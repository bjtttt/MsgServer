-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([process_vdr_data/3]).

-include("ti_header.hrl").
-include("mysql.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Socket, Addr]) ->
    process_flag(trap_exit, true),
    Pid = self(),
    State = #vdritem{socket=Socket, pid=Pid, addr=Addr, msgflownum=0, errorcount=0},
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
%%%
%%%
handle_info({tcp, Socket, Data}, OriginalState) ->
    % Update active time for VDR
    DateTime = {erlang:date(), erlang:time()},
    State = OriginalState#vdritem{acttime=DateTime},
    %Data = <<126,1,2,0,2,1,86,121,16,51,112,0,14,81,82,113,126>>,
    Messages = ti_common:split_msg_to_single(Data, 16#7e),
    case Messages of
        [] ->
            % Max 3 vdrerrors are allowed
            ErrorCount = State#vdritem.errorcount + 1,
            NewState = State#vdritem{errorcount=ErrorCount},
            if
                ErrorCount >= ?MAX_VDR_ERR_COUNT ->
                    {stop, vdrerror, NewState};
                true ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, NewState}
            end;
        _ ->
            case process_vdr_msges(Socket, Messages, State) of
                {error, vdrerror, NewState} ->
                    % Max 3 vdrerrors are allowed
                    ErrorCount = NewState#vdritem.errorcount + 1,
                    UpdatedState = NewState#vdritem{errorcount=ErrorCount},
                    if
                        ErrorCount >= ?MAX_VDR_ERR_COUNT ->
                            {stop, vdrerror, UpdatedState};
                        true ->
                            inet:setopts(Socket, [{active, once}]),
                            {noreply, UpdatedState}
                    end;
                {error, ErrorType, NewState} ->
                    {stop, ErrorType, NewState};
                {warning, NewState} ->
                    UpdatedState = NewState#vdritem{errorcount=0},
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, UpdatedState};
                {ok, NewState} ->
                    UpdatedState = NewState#vdritem{errorcount=0},
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, UpdatedState}
            end
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
    case Socket of
        undefined ->
            ok;
        _ ->
            ets:delete(vdrtable, Socket)
    end,
    case ID of
        undefined ->
            ok;
        _ ->
            ets:delete(vdridsocktable, ID),
            {ok, WSUpdate} = wsock_data_parser:create_term_offline([ID]),
            wsock_client:send(WSUpdate)
    end,
    case Auth of
        undefined ->
            ok;
        _ ->
            Sql = list_to_binary([<<"update device set is_online=0 where authen_code='">>, list_to_binary(Auth), <<"'">>]),
            send_sql_to_db(conn, Sql)
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
%%% Return :
%%%     {ok, State}
%%%     {warning, State}
%%%     {error, dberror/wserror/vdrerror/invaliderror/systemerror/exception/unknown, State}  
%%%
process_vdr_msges(Socket, Msges, State) ->
    [H|T] = Msges,
    Result = safe_process_vdr_msg(Socket, H, State),
    case T of
        [] ->
            Result;
        _ ->
            case Result of
                {ok, NewState} ->
                    safe_process_vdr_msg(Socket, T, NewState);
                {warning, NewState} ->
                    safe_process_vdr_msg(Socket, T, NewState);
                {error, ErrorType, NewState} ->
                    {error, ErrorType, NewState};
                _ ->
                    {error, unknown, State}
            end
    end.

%%%
%%% Return :
%%%     {ok, State}
%%%     {warning, State}
%%%     {error, dberror/wserror/systemerror/vdrerror/invaliderror/exception, State}  
%%%
safe_process_vdr_msg(Socket, Msg, State) ->
    try process_vdr_data(Socket, Msg, State)
    catch
        _ ->
            {error, exception, State}
    end.

%%%
%%% This function should refer to the document on the mechanism
%%%
%%% Return :
%%%     {ok, State}
%%%     {warning, State}
%%%     {error, dberror/wserror/systemerror/vdrerror/invaliderror/exception, State}  
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
                            case create_sql_from_vdr(HeadInfo, Msg) of
                                {ok, Sql} ->
                                    % We should check whether fetch works or not
                                    _SqlResp = send_sql_to_db(conn, Sql),
                                    
                                    % Should check whether the registration is OK or not and send response accordingly
                                    
                                    FlowIdx = State#vdritem.msgflownum,
                                    send_resp_to_vdr(16#8001, Socket, ID, MsgIdx, FlowIdx, ?T_GEN_RESP_OK),
                                    
                                    {ok, State#vdritem{msgflownum=FlowIdx+1, msg2vdr=[], msg=[], req=[]}};
                                _ ->
                                    {error, vdrerror, State}
                            end;
                        16#102 ->
                            % VDR Authentication
                            case create_sql_from_vdr(HeadInfo, Msg) of
                                {ok, Sql} ->
                                    SqlResp = send_sql_to_db(conn, Sql),
                                    case extract_db_resp(SqlResp) of
                                        {ok, empty} ->
                                            {error, dberror, State};
                                        {ok, Recs} ->
                                            RecsLen = length(Recs),
                                            case RecsLen of
                                                1 ->
                                                    [Rec] = Recs,
                                                    case get_db_resp_record_field(Rec, list_to_binary("id")) of
                                                        {ok, {<<"id">>, Value}} ->
                                                            {Auth} = Msg,
                                                            
                                                            % Not tested yet.
                                                            IDSockList = ets:lookup(vdridsocktable, Value),
                                                            disconn_socket_by_id(IDSockList),
                                                            IDSock = #vdridsockitem{id=Value, socket=Socket, addr=State#vdritem.addr},
                                                            ets:insert(vdridsocktable, IDSock),
                                                            SockVdrList = ets:lookup(vdrtable, Socket),
                                                            case length(SockVdrList) of
                                                                1 ->
                                                                    [SockVdr] = SockVdrList,
                                                                    ets:insert(vdridsocktable, SockVdr#vdritem{id=Value, auth=Auth}),
                                                                    
                                                                    SqlUpdate = list_to_binary([<<"update device set is_online=1 where authen_code='">>, list_to_binary(Auth), <<"'">>]),
                                                                    send_sql_to_db(conn, SqlUpdate),
                                                                    
                                                                    case wsock_data_parser:create_term_online([Value]) of
                                                                        {ok, WSUpdate} ->
                                                                            wsock_client:send(WSUpdate),
                                                                    
                                                                            FlowIdx = State#vdritem.msgflownum,
                                                                            send_resp_to_vdr(16#8001, Socket, ID, MsgIdx, FlowIdx, ?T_GEN_RESP_OK),
                                                
                                                                            {ok, State#vdritem{id=Value, auth=Auth, msgflownum=FlowIdx+1, msg2vdr=[], msg=[], req=[]}};
                                                                        _ ->
                                                                            {error, wserror, State}
                                                                    end;
                                                                _ ->
                                                                    % vdrtable or vdridsocktable error
                                                                    {error, systemerror, State}
                                                            end;
                                                        _ ->
                                                            % DB includes no "id" field in the device record
                                                            {error, dberror, State}
                                                    end;
                                                _ ->
                                                    % DB includes more than on records with the same authen_code 
                                                    {error, dberror, State}
                                            end;
                                        _ ->
                                            % DB includes no record with the given authen_code
                                            {error, dberror, State}
                                    end;
                                _ ->
                                    % Authentication fails
                                    {error, invaliderror, State}
                            end;
                        true ->
                            % Unauthorized/Unregistered VDR can only accept 16#100/16#102
                            {error, invaliderror, State}
                    end;
                true ->
                    case ID of
                        16#1 ->     % VDR general response
                            {GwFlowIdx, GwID, GwRes} = Msg,
                            
                            % Process reponse from VDR here

                            {ok, NewState};                      
                        16#2 ->     % VDR pulse
                            % Nothing to do here
                            %{} = Msg,
                            {ok, NewState};
                        16#3 ->     % VDR unregistration
                            %{} = Msg,
                            Auth = State#vdritem.auth,
                            ID = State#vdritem.id,
                            Sql = create_sql_from_vdr(HeadInfo, {ID, Auth}),
                            send_sql_to_db(conn, Sql),
                            
                            % return error to terminate connection with VDR
                            {error, invaliderror, NewState};
                        16#104 ->   % VDR parameter query
                            {RespIdx, ActLen, List} = Msg,
                            
                            % Process response from VDR here
                            
                            {ok, NewState};
                        16#107 ->   % VDR property query
                            {Type, ProId, Model, TerId, ICCID, HwVerLen, HwVer, FwVerLen, FwVer, GNSS, Prop} = Msg,
                            
                            % Process response from VDR here

                            {ok, NewState};
                        16#108 ->
                            {Type, Res} = Msg,
                            
                            % Process response from VDR here
                            
                            {ok, NewState};
                        16#200 ->
                            {H, AppInfo} = Msg,
                            [AlarmSym, State, Lat, Lon, Height, Speed, Direction, Time] = H,
                            
                            FlowIdx = State#vdritem.msgflownum,
                            send_resp_to_vdr(16#8001, Socket, ID, MsgIdx, FlowIdx, ?T_GEN_RESP_OK),
                            
                            {ok, NewState#vdritem{msgflownum=FlowIdx+1}};
                        16#201 ->
                            {RespNum, PosMsg} = Msg,
            
                            {ok, NewState};
                        16#301 ->
                            {Id} = Msg,
                            
                            {ok, NewState};
                        16#302 ->
                            {Id} = Msg,
                            
                            {ok, NewState};
                        16#303 ->
                            {MsgType,POC} = Msg,
                            
                            {ok, NewState};
                        16#500 ->
                            {FlowNum, Resp} = Msg,
                            
                            {ok, NewState};
                        16#700 ->
                            {Number,OrderWord,DB} = Msg,
                            
                            {ok, NewState};
                        16#701 ->
                            {Length,Content} = Msg,
                            
                            {ok, NewState};
                        16#702 ->
                            {DrvState,Time,IcReadResult,NameLen,N,CerNum,OrgLen,O,Validity} = Msg,
                            
                            {ok, NewState};
                        16#704 ->
                            {Len,Type,Positions} = Msg,
                            
                            {ok, NewState};
                        16#705 ->
                            {Count, Time, Data} = Msg,
                            
                            {ok, NewState};
                        16#800 ->
                            {Id,Type,Code,EICode,PipeId} = Msg,
                            
                            {ok, NewState};
                        16#801 ->
                            {Id,Type,Code,EICode,PipeId,MsgBody,Pack} = Msg,
                            
                            {ok, NewState};
                        16#805 ->
                            {RespIdx, Res, ActLen, List} = Msg,
                            
                            {ok, NewState};
                        16#802 ->
                            {FlowNum, Len, Data} = Msg,
                            
                            {ok, NewState};
                        16#900 ->
                            {Type,Con} = Msg,
                            
                            {ok, NewState};
                        16#901 ->
                            {Len,Body} = Msg,
                            
                            {ok, NewState};
                        16#A00 ->
                            {E,N} = Msg,
                            
                            {ok, NewState};
                        _ ->
                            {ok, NewState}
                    end
                    %Sql = create_sql_from_vdr(HeadInfo, Msg),
                    %send_sql_to_db(conn, Sql),
                    
                    %FlowIdx = State#vdritem.msgflownum,
                    %send_resp_to_vdr(16#8001, Socket, ID, MsgIdx, FlowIdx, ?T_GEN_RESP_OK),

                    %{ok, NewState#vdritem{msgflownum=FlowIdx+1}}
            end;
        {ignore, HeaderInfo, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            send_resp_to_vdr(16#8001, Socket, ID, MsgIdx, FlowIdx, ?T_GEN_RESP_OK),
            
            {ok, NewState#vdritem{msgflownum=FlowIdx+1}};
        {warning, HeaderInfo, ErrorType, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            send_resp_to_vdr(16#8001, Socket, ID, MsgIdx, FlowIdx, ErrorType),
            
            {warning, NewState#vdritem{msgflownum=FlowIdx+1}};
        {error, _ErrorType, NewState} ->    % exception/parityerror/formaterror
            {error, vdrerror, NewState}
    end.

%%%
%%% Parameters :
%%%     Socket      : VDR Socket
%%%     VDRMsgID    :
%%%     VDRMsgIdx   :
%%%     FlowIdx     : Gateway Msg Idx
%%%     Type        :
%%%
%%% Type :
%%%     ?T_GEN_RESP_OK
%%%     ?T_GEN_RESP_FAIL
%%%     ?T_GEN_RESP_ERRMSG
%%%     ?T_GEN_RESP_NOTSUPPORT
%%%
send_resp_to_vdr(RespType, Socket, VDRMsgID, VDRMsgIdx, FlowIdx, Type) ->
    if
        Type =/= ?T_GEN_RESP_OK andalso Type =/= ?T_GEN_RESP_FAIL andalso Type =/= ?T_GEN_RESP_ERRMSG andalso Type =/= ?T_GEN_RESP_NOTSUPPORT ->
            ok;
        true ->
            MsgBody = vdr_data_processor:create_gen_resp(VDRMsgID, VDRMsgIdx, Type),
            VDRResp = vdr_data_processor:create_final_msg(RespType, FlowIdx, MsgBody),
           send_data_to_vdr(Socket, VDRResp)
    end.

%%%
%%% Diconnect socket and remove related entries from vdrtable and vdridsocktable
%%%
disconn_socket_by_id(IDSockList) ->
    case IDSockList of
        [] ->
            ok;
        _ ->
            [H|T] = IDSockList,
            ID = H#vdridsockitem.id,
            Sock = H#vdridsockitem.socket,
            try gen_tcp:close(Sock)
            catch
                _ ->
                    ok
            end,
            ets:delete(vdrtable, Sock),
            ets:delete(vdridsocktable, ID),
            case T of
                [] ->
                    ok;
                _ ->
                    disconn_socket_by_id(T)
            end
    end.
           
%%%
%%%
%%%
send_data_to_vdr(Socket, Msg) ->
    gen_tcp:send(Socket, Msg).
    %gen_server:cast(?MODULE, {send, Socket, Msg}).

%%%
%%%
%%%
send_sql_to_db(PoolId, Msg) ->
    mysql:fetch(PoolId, Msg).
    %gen_server:call(?MODULE, {fetch, PoolId, Msg}).

%%%         
%%% Return :
%%%     {ok, SQL}
%%%     {error, iderror}
%%%     error
%%%
create_sql_from_vdr(HeaderInfo, Msg) ->
    {ID, _FlowNum, _TelNum, _CryptoType} = HeaderInfo,
    case ID of
        16#1    ->
            {ok, ""};
        16#2    ->                          
            {ok, ""};
        16#100  ->                          
            {Province, City, Producer, TermModel, TermID, LicColor, LicID} = Msg,
            {ok, ""};
        16#3    ->                          
            {ID, Auth} = Msg,
            {ok, list_to_binary([<<"delete from device where authen_code='">>, list_to_binary(Auth), <<"' or id='">>, list_to_binary(ID), <<"'">>])};
        16#102  ->
            {Auth} = Msg,
            {ok, list_to_binary([<<"select * from device where authen_code='">>, list_to_binary(Auth), <<"'">>])};
        16#104  ->
            {RespIdx, ActLen, List} = Msg,
            {ok, ""};
        16#107  ->
            {Type, ProId, Model, TerId, ICCID, HwVerLen, HwVer, FwVerLen, FwVer, GNSS, Prop} = Msg,
            {ok, ""};
        16#108  ->    
            {Type, Res} = Msg,
            {ok, ""};
        16#200  ->
            case Msg of
                {H} ->
                    [AlarmSym, State, Lat, Lon, Height, Speed, Direction, Time] = H,
                    {ok, ""};
                {H, AppInfo} ->
                    [AlarmSym, State, Lat, Lon, Height, Speed, Direction, Time]= H,
                    {ok, ""}
            end;
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
                Result ->
                    case T of
                        [] ->
                            [Result];
                        _ ->
                            [Result|compose_db_resp_records(ColDef, T)]
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
            {Key, Value} = H,
            if
                Key == Field ->
                    {ok, {Key, Value}};
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
%check_db_update(Msg) ->
%    case Msg of
%        {update, {mysql_result, _, _, AffectedRows, _, _, _, _}} ->
%            {ok, AffectedRows};
%        _ ->
%            error
%    end.

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


