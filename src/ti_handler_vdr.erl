-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Socket, Addr]) ->
    %process_flag(trap_exit, true),
    Pid = self(),
    VDRPid = spawn(fun() -> data2vdr_process(Pid, Socket) end),
    State = #vdritem{socket=Socket, pid=Pid, vdrpid=VDRPid, addr=Addr, msgflownum=0},
    ets:insert(vdrtable, State), 
    inet:setopts(Socket, [{active, once}]),
	{ok, State}.

handle_call(_Request, _From, State) ->
	{noreply, ok, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

%%%
%%% VDR handler receives date from VDR
%%% Steps :
%%%     1. Parse the data
%%%     2. Check whether it is ID reporting message
%%%         YES -> 
%%%             Update the vdritem record
%%%         NO ->
%%%             A. Check whether the VDR has reported ID or not
%%%                 YES ->
%%%                     a. Send it to the DB
%%%                     b. Check whether it is a management reporting message
%%%                         YES ->
%%%                             Report the data to the management platform
%%%                         NO ->
%%%                             Do nothing
%%%                 NO ->
%%%                     a. Discard the data
%%%                     b. Request ID reporting message (REALLY NEEDED?)
%%%
%%% Still in design
%%%
handle_info({tcp, Socket, Data}, State) ->
    case process_vdr_data(Socket, Data, State) of
        {error, dberror, NewState} ->
            {stop, dbprocerror, NewState};
        {error, logicerror, NewState} ->
            inet:setopts(Socket, [{active, once}]),
            {noreply, NewState};
        {warning, NewState} ->
            inet:setopts(Socket, [{active, once}]),
            {noreply, NewState};
        {ok, NewState} ->
            inet:setopts(Socket, [{active, once}]),
            {noreply, NewState}
    end;
handle_info({tcp_closed, _Socket}, State) ->    
    ti_common:loginfo("VDR (~p) : TCP is closed~n"),
    % return stop will invoke terminate(Reason,State)
    % tcp_closed will be transfered as Reason
	{stop, tcp_closed, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

%%%
%%% When VDR handler process is terminated, do the clean jobs here
%%%
terminate(Reason, State) ->
    VDRPid = State#vdritem.vdrpid,
    case VDRPid of
        undefined ->
            ok;
        _ ->
            VDRPid!stop
    end,
	try gen_tcp:close(State#vdritem.socket)
    catch
        _:Ex ->
            ti_common:logerror("VDR (~p) : Exception when closing TCP : ~p~n", [State#vdritem.addr, Ex])
    end,
    ti_common:loginfo("VDR (~p) : VDR handler process (~p) is terminated : ~p~n", [State#vdritem.addr, State#vdritem.pid, Reason]).

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}.

%%%
%%% This function should refer to the document on the mechanism
%%%
%%% Return :
%%%     {ok, State}
%%%     {ok, Resp, State}
%%%     {warning, State}
%%%     {error, dberror/logicerror, State}  
%%%         1. when DB connection process is not available
%%%         2. when VDR ID is unavailable
%%%         In either case, the connection with VDR will be closed by the server.
%%%
%%% Still in design
%%%
process_vdr_data(Socket, Data, State) ->
    % We should check whether the "DB Process PID" and the "VDR ID" is available or not.
    % If "DB Process PID" is unavailable, we should terminate the current VDR connection as soon as possible.
    % If "VDR ID" is unavailable, we should check the current message is for registration or login.
    VDRID = State#vdritem.id,
    VDRPid = State#vdritem.vdrpid,
    [{dbconnpid, DBProcessPid}] = ets:lookup(msgservertable, dbconnpid),
    case DBProcessPid of
        undefined ->
            ti_common:logerror("VDR from ~p is disconnected because DB client is unavailable~n", [State#vdritem.addr]),
            {error, dberror, State};
        _ ->
            case ti_vdr_data_parser:process_data(State, Data) of
                {ok, HeaderInfo, Msg, NewState} ->
                    {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
                    if
                        VDRID == undefined ->
                            case ID of
                                16#100 ->
                                    % Register VDR
                                    %{Province, City, Producer, TermModel, TermID, LicColor, LicID} = Msg,
                                    DBMsg = compose_db_msg(HeaderInfo, Msg),
                                    DBProcessPid!DBMsg,
                                    case receive_db_process_msg(DBProcessPid, 0) of
                                        {ok, DBResp} ->
                                            VDRPid!{ok, {ID, MsgIdx, ?T_GEN_RESP_OK}},
                                            % We don't need to wait for the response here if the original msg is from the VDR instead of the management platform
                                            {ok, NewState#vdritem{msg2vdr=[], msg=[], req=[]}};
                                        error ->
                                            {error, dberror, NewState}
                                    end;
                                16#102 ->
                                    % VDR Authentication
                                    {Auth} = Msg,
                                    DBMsg = compose_db_msg(HeaderInfo, Msg),
                                    DBProcessPid!DBMsg,
                                    case receive_db_process_msg(DBProcessPid, 0) of
                                        {ok, DBResp} ->
                                            % We should check the DB response to verify the authentication.
                                            % No codes yet.
                                            IDSockList = ets:lookup(vdridsocktable, Auth),
                                            disconnect_socket_by_id(IDSockList),
                                            IDSock = #vdridsockitem{id=Auth, socket=Socket, addr=State#vdritem.addr},
                                            ets:insert(vdridsocktable, IDSock),
                                            VDRPid!{ok, {ID, MsgIdx, ?T_GEN_RESP_OK}},
                                            % We don't need to wait for the response here if the original msg is from the VDR instead of the management platform
                                            {ok, NewState#vdritem{id=Auth, msg2vdr=[], msg=[], req=[]}};
                                        error ->
                                            {error, dberror, NewState}
                                    end;
                                true ->
                                     {error, logicerror, State}
                            end;
                        true ->
                            DBMsg = compose_db_msg(HeaderInfo, Msg),
                            DBProcessPid!DBMsg,
                            case receive_db_process_msg(DBProcessPid, 0) of
                                ok ->
                                    VDRPid!{ok, {ID, MsgIdx, ?T_GEN_RESP_OK}},
                                    {ok, NewState};
                                error ->
                                    {error, dberror, NewState}
                            end
                    end;
                {ignore, HeaderInfo, NewState} ->
                    {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
                    VDRPid!{ok, {ID, MsgIdx, ?T_GEN_RESP_OK}},
                    {ok, NewState};
                {warning, HeaderInfo, ErrorType, NewState} ->
                    {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
                    VDRPid!{ok, {ID, MsgIdx, ErrorType}},
                    {warning, NewState};
                {error, dataerror, NewState} ->
                    {error, logicerror, NewState};
                {error, exception, NewState} ->
                    {error, logicerror, NewState}
            end
    end.

disconnect_socket_by_id(IDSockList) ->
    case IDSockList of
        [] ->
            ok;
        _ ->
            [H|T] = IDSockList,
            ID = H#vdridsockitem.id,
            Sock = H#vdridsockitem.socket,
            Addr = H#vdridsockitem.addr,
            try gen_tcp:close(Sock)
            catch
                _:Ex ->
                    ti_common:logerror("Exception when closing duplicated VDR from ~p : ~p~n", [Addr, Ex])
            end,
            ets:delete(vdrtable, Sock),
            ets:delete(vdridsocktable, ID),
            disconnect_socket_by_id(T)
    end.
                

%%%
%%% Try to receive response from the DB connection process at most 10 times.
%%% Do we need _Resp from the DB connection process?
%%% Return :
%%%     {ok, Resp}
%%%     {fail, Resp}
%%%     error
%%%
receive_db_process_msg(DBProcessPid, ErrorCount) ->
    if
        ErrorCount < ?DB_PROCESS_TRIAL_MAX ->
            receive
                {From, Resp} ->
                    if
                        From == DBProcessPid ->
                            {ok, Resp};
                        From =/= DBProcessPid ->
                            receive_db_process_msg(DBProcessPid, ErrorCount+1)
                    end;
                _ ->
                    receive_db_process_msg(DBProcessPid, ErrorCount+1)
            after ?TIMEOUT_DATA_DB ->
                    receive_db_process_msg(DBProcessPid, ErrorCount+1)
            end;
        ErrorCount >= ?DB_PROCESS_TRIAL_MAX ->
            error
    end.
            
%%%         
%%%
%%%
compose_db_msg(HeaderInfo, _Resp) ->
    {ID, _FlowNum, _TelNum, _CryptoType} = HeaderInfo,
    case ID of
        1 ->
            ok;
        2 ->
            ok;
        _ ->
            error
    end.

%%%
%%% This process is send msg from the management to the VDR.
%%% Each time when sending msg from the management to the VDR, a flag should be set in vdritem.
%%% If the ack from the VDR is received in handle_info({tcp,Socket,Data},State), this flag will be cleared.
%%% After the defined TIMEOUT is achived, it means VDR cannot response and the TIMEOUT should be adjusted and this msg will be sent again.
%%% (Please refer to the specification for this mechanism.)
%%%
%%% Still in design
%%%
data2vdr_process(Pid, Socket) ->
    receive
        {FromPid, {ok, Data}} ->
            if 
                FromPid == Pid ->
                    {ID, MsgIdx, Res} = Data,
                    case ti_vdr_msg_body_processor:create_general_response(ID, MsgIdx, Res) of
                        {ok, Bin} ->
                            gen_tcp:send(Socket, Bin);
                        error ->
                            ti_common:logerror("Data2VDR process : message type error unknown PID ~p : ~p~n", [FromPid, Res])
                    end;
                FromPid =/= Pid ->
                    ti_common:logerror("Data2VDR process : message from unknown PID ~p : ~p~n", [FromPid, Data])
            end,        
            data2vdr_process(Pid, Socket);
        {FromPid, {data, Data}} ->
            if 
                FromPid == Pid ->
                    gen_tcp:send(Socket, Data);
                FromPid =/= Pid ->
                    ti_common:logerror("VDR server send data to VDR process : message from unknown PID ~p : ~p~n", [FromPid, Data])
            end,        
            data2vdr_process(Pid, Socket);
        {FromPid, Data} ->
            ti_common:logerror("VDR server send data to VDR process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            data2vdr_process(Pid, Socket);
        stop ->
            ok
    after ?TIMEOUT_DATA_VDR ->
        %ti_common:loginfo("VDR server send data to VDR process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
        data2vdr_process(Pid, Socket)
    end.

%%%
%%% Compose body, header and parity
%%% Calculate XOR value
%%% 0x7d -> 0x7d0x1 & 0x7e -> 0x7d0x2
%%%
%%% return {Response, NewState}
%%%
createresp(HeaderInfo, Result, State) ->
    {ID, FlowNum, TelNum, CryptoType} = HeaderInfo,
    RespFlowNum = State#vdritem.msgflownum,
    Body = <<FlowNum:16, ID:16, Result:8>>,
    BodyLen = bit_size(Body),
    BodyProp = <<0:2, 0:1, CryptoType:3, BodyLen:10>>,
    Header = <<128, 1, BodyProp:16, TelNum:48, RespFlowNum:16>>,
    HeaderBody = <<Header, Body>>,
    XOR = ti_vdr_data_parser:bxorbytelist(HeaderBody),
    RawData = binary:replace(<<HeaderBody, XOR>>, <<125>>, <<125,1>>, [global]),
    RawDataNew = binary:replace(RawData, <<126>>, <<125,2>>, [global]),
    {<<126, RawDataNew, 126>>, State#vdritem{msgflownum=RespFlowNum+1}}.


