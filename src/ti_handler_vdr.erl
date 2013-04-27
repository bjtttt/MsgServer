-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").
-include("mysql.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Socket, Addr]) ->
    process_flag(trap_exit, true),
    Pid = self(),
    State = #vdritem{socket=Socket, pid=Pid, addr=Addr, msgflownum=0},
    ets:insert(vdrtable, State), 
    inet:setopts(Socket, [{active, once}]),
	{ok, State}.

handle_call({fetch, PoolId, Msg}, _From, State) ->
    Resp = mysql:fetch(PoolId, Msg),
    {noreply, {ok, Resp}, State};
handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast({send, Socket, Msg}, State) ->
    gen_tcp:send(Socket, Msg),
    {noreply, State};
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
            {stop, dbclierror, NewState};
        {error, wserror, NewState} ->
            {stop, wsclirror, NewState};
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
    ID = State#vdritem.id,
    Auth = State#vdritem.auth,
    Socket = State#vdritem.socket,
    ets:delete(vdrtable, Socket),
    ets:delete(vdridsocktable, ID),
    DBUpdate = [<<"update device set is_online=0 where authen_code='">>, Auth, <<"'">>],
    RespUpdate = send_data_to_db(conn, DBUpdate),
    case check_db_update(RespUpdate) of
        {ok, AffectedRows} ->
            if
                AffectedRows == 1 ->
                    ok;
                true ->
                    ok
            end;
        _ ->
            ok
    end,
    {ok, WSUpdate} = wsock_data_parser:create_term_offline([ID]),
    wsock_client:send(WSUpdate),
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
%%%     {error, dberror/dbresperror/dbstructerror/wserror/logicerror, State}  
%%%         1. when DB client process is not available
%%%         1. when Websocket client process is not available
%%%         2. when VDR ID is unavailable
%%%         In either case, the connection with VDR will be closed by the server.
%%%
%%% Still in design
%%%
process_vdr_data(Socket, Data, State) ->
    VDRID = State#vdritem.id,
    case vdr_data_parser:process_data(State, Data) of
        {ok, HeadInfo, Msg, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeadInfo,
            if
                VDRID == undefined ->
                    case ID of
                        16#100 ->
                            % Register VDR
                            %{Province, City, Producer, TermModel, TermID, LicColor, LicID} = Msg,
                            % We should check whether fetch works or not
                            DBMsg = compose_db_msg(HeadInfo, Msg),
                            Resp = send_data_to_db(conn, DBMsg),
                            
                            VDRResp = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            send_data_to_vdr(Socket, VDRResp),
                            
                            {ok, NewState#vdritem{msg2vdr=[], msg=[], req=[]}};
                        16#102 ->
                            % VDR Authentication
                            DBMsg = compose_db_msg(HeadInfo, Msg),
                            Resp = send_data_to_db(conn, DBMsg),
                            case extract_db_resp(Resp) of
                                {ok, empty} ->
                                    {error, operinvalid, State};
                                {ok, Records} ->
                                    RecordsLen = length(Records),
                                    case RecordsLen of
                                        1 ->
                                            [Record] = Records,
                                            case get_db_resp_record_field(Record, list_to_binary("id")) of
                                                {_Key, Value} ->
                                                    {Auth} = Msg,
                                                    IDSockList = ets:lookup(vdridsocktable, Auth),
                                                    disconnect_socket_by_id(IDSockList),
                                                    IDSock = #vdridsockitem{id=Auth, socket=Socket, addr=State#vdritem.addr},
                                                    ets:insert(vdridsocktable, IDSock),
                                                    
                                                    DBUpdate = [<<"update device set is_online=1 where authen_code='">>, Auth, <<"'">>],
                                                    RespUpdate = send_data_to_db(conn, DBUpdate),
                                                    case check_db_update(RespUpdate) of
                                                        {ok, AffectedRows} ->
                                                            if
                                                                AffectedRows == 1 ->
                                                                    {ok, WSUpdate} = wsock_data_parser:create_term_online([Value]),
                                                                    wsock_client:send(WSUpdate),
                                                                    
                                                                    VDRResp = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                                                                    send_data_to_vdr(Socket, VDRResp),
                                        
                                                                    {ok, NewState#vdritem{id=Value, auth=Auth, msg2vdr=[], msg=[], req=[]}};
                                                                true ->
                                                                    {error, dbstructerror, State}
                                                            end;
                                                        error ->
                                                            {error, dbresperror, State}
                                                    end;
                                                _ ->
                                                    {error, dbstructerror, State}
                                            end;
                                        _ ->
                                            {error, dbstructerror, State}
                                    end;
                                _ ->
                                    {error, dbresperror, State}
                            end;
                        true ->
                            VDRResp = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_ERRMSG),
                            send_data_to_vdr(Socket, VDRResp),

                            {error, logicerror, State}
                    end;
                true ->
                    DBMsg = compose_db_msg(HeadInfo, Msg),
                    send_data_to_db(conn, DBMsg),

                    VDRResp = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                    send_data_to_vdr(Socket, VDRResp),

                    {ok, NewState}
            end;
        {ignore, HeaderInfo, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            VDRResp = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
            send_data_to_vdr(Socket, VDRResp),
            {ok, NewState};
        {warning, HeaderInfo, ErrorType, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            VDRResp = vdr_data_processor:create_gen_resp(ID, MsgIdx, ErrorType),
            send_data_to_vdr(Socket, VDRResp),
            {warning, NewState};
        {error, dataerror, NewState} ->
            {error, logicerror, NewState};
        {error, exception, NewState} ->
            {error, logicerror, NewState}
    end.

%%%
%%%
%%%
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
%%%
%%%
send_data_to_vdr(Socket, Msg) ->
    gen_server:cast(?MODULE, {send, Socket, Msg}).

%%%
%%%
%%%
send_data_to_db(PoolId, Msg) ->
    gen_server:call(?MODULE, {fetch, PoolId, Msg}).

%%%         
%%%
%%%
compose_db_msg(HeaderInfo, Msg) ->
    {ID, _FlowNum, _TelNum, _CryptoType} = HeaderInfo,
    case ID of
        16#1    ->                          
            {ok, ""};
        16#2    ->                          
            {ok, ""};
        16#100  ->                          
            {ok, ""};
        16#3    ->                          
            {ok, ""};
        16#102  ->
            {Auth} = Msg,
            {ok, [<<"select * from device where authen_code='">>, Auth, <<"'">>]};
        16#104  ->                          
            {ok, ""};
        16#107  ->                      
            {ok, ""};
        16#108  ->                          
            {ok, ""};
        16#200  ->                      
            {ok, ""};
        16#201  ->                          
            {ok, ""};
        16#301  ->                          
            {ok, ""};
        16#302  ->
            {ok, ""};
        16#303  ->
            {ok, ""};
        16#500  ->
            {ok, ""};
        16#700  ->
            {ok, ""};
        16#701  ->
            {ok, ""};
        16#702  ->
            {ok, ""};
        16#704  ->
            {ok, ""};
        16#705  ->
            {ok, ""};
        16#800  ->
            {ok, ""};
        16#801  ->
            {ok, ""};
        16#802  ->
            {ok, ""};
        16#805  ->
            {ok, ""};
        16#900 ->
            {ok, ""};
        16#901 ->
            {ok, ""};
        16#a00 ->
            {ok, ""};
        _ ->
            {error, iderror}
    end.

%%%
%%% Parameter :
%%% {data, {mysql_result, ColumnDefition, Results, AffectedRows, InsertID, Error, ErrorCode, ErrorSqlState}}
%%% Results = [[Record0], [Record1], [Record2], ...]
%%%
%%% Return :
%%%     {ok, RecordPairs} 
%%%     {ok, empty} 
%%%     error 
%%%
extract_db_resp(Msg) ->
    case Msg of
        {data, {mysql_result, ColDef, Res, _, _, _, _, _}} ->
            case Res of
                [] ->
                    {ok, empty};
                _ ->
                    {ok, compose_db_resp_records(ColDef, Res)}
            end;
        _ ->
            error
    end.

%%%
%%%
%%%
compose_db_resp_records(ColDef, Res) ->
    case Res of
        [] ->
            [];
        _ ->
            [H|T] = Res,
            case compose_db_resp_record(ColDef, H) of
                error ->
                    case T of
                        [] ->
                            [];
                        _ ->
                            compose_db_resp_records(ColDef, T)
                    end;
                _ ->
                    case compose_db_resp_record(ColDef, H) of
                        error ->
                            case T of
                                [] ->
                                    [];
                                _ ->
                                    compose_db_resp_records(ColDef, T)
                            end;
                        Record ->
                            case T of
                                [] ->
                                    [];
                                _ ->
                                    [Record|compose_db_resp_records(ColDef, T)]
                            end
                    end
            end
    end.

%%%
%%%
%%%
compose_db_resp_record(ColDef, Res) ->
    Len1 = length(ColDef),
    Len2 = length(Res),
    if
        Len1 == Len2 ->
            case ColDef of
                [] ->
                    [];
                _ ->
                    [H1|T1] = ColDef,
                    [H2|T2] = Res,
                    {_Tab, ColName, _Len, _Type} = H1,
                    case T1 of
                        [] ->
                            [{ColName, H2}];
                        _ ->
                            [{ColName, H2}|compose_db_resp_record(T1, T2)]
                    end
            end;
        true ->
            error
    end.

%%%
%%%
%%%
get_db_resp_record_field(Record, Field) ->
    case Record of
        [] ->
            error;
        _ ->
            [H|T] = Record,
            [Key, Value] = H,
            if
                Key == Field ->
                    {Key, Value};
                true ->
                    case T of
                        [] ->
                            error;
                        _ ->
                            get_db_resp_record_field(T, Field)
                    end
            end
    end.                    

%%%
%%% {update, {mysql_result, ColumnDefition, Results, AffectedRows, InsertID, Error, ErrorCode, ErrorSqlState}}
%%%
%%% Return :
%%%     {ok, AffectedRows}
%%%     error
%%%
check_db_update(Msg) ->
    case Msg of
        {update, {mysql_result, _, _, AffectedRows, _, _, _, _}} ->
            {ok, AffectedRows};
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
%data2vdr_process(Pid, Socket) ->
%    receive
%        {FromPid, {ok, Data}} ->
%            if 
%                FromPid == Pid ->
%                    {ID, MsgIdx, Res} = Data,
%                    case vdr_data_processor:create_gen_resp(ID, MsgIdx, Res) of
%                        {ok, Bin} ->
%                            gen_tcp:send(Socket, Bin);
%                        error ->
%                            ti_common:logerror("Data2VDR process : message type error unknown PID ~p : ~p~n", [FromPid, Res])
%                    end;
%                FromPid =/= Pid ->
%                    ti_common:logerror("Data2VDR process : message from unknown PID ~p : ~p~n", [FromPid, Data])
%            end,        
%            data2vdr_process(Pid, Socket);
%        {FromPid, {data, Data}} ->
%            if 
%                FromPid == Pid ->
%                    gen_tcp:send(Socket, Data);
%                FromPid =/= Pid ->
%                    ti_common:logerror("VDR server send data to VDR process : message from unknown PID ~p : ~p~n", [FromPid, Data])
%            end,        
%            data2vdr_process(Pid, Socket);
%        {FromPid, Data} ->
%            ti_common:logerror("VDR server send data to VDR process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
%            data2vdr_process(Pid, Socket);
%        stop ->
%            ok
%    after ?TIMEOUT_DATA_VDR ->
%        %ti_common:loginfo("VDR server send data to VDR process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
%        data2vdr_process(Pid, Socket)
%    end.

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
    XOR = vdr_data_parser:bxorbytelist(HeaderBody),
    RawData = binary:replace(<<HeaderBody, XOR>>, <<125>>, <<125,1>>, [global]),
    RawDataNew = binary:replace(RawData, <<126>>, <<125,2>>, [global]),
    {<<126, RawDataNew, 126>>, State#vdritem{msgflownum=RespFlowNum+1}}.


