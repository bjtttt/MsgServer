-module(vdr_handler).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([process_vdr_data/3]).

-include("header.hrl").
-include("mysql.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Socket, Addr]) ->
    process_flag(trap_exit, true),
    Pid = self(),
    [{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
    [{wspid, WSPid}] = ets:lookup(msgservertable, wspid),
    State = #vdritem{socket=Socket, pid=Pid, addr=Addr, msgflownum=0, errorcount=0, dbpid=DBPid, wspid=WSPid},
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
handle_info({tcp, Socket, Data}, OriState) ->
    common:loginfo("Data from VDR (~p) (id:~p, serialno:~p, authen_code:~p) : ~p~n", [OriState#vdritem.addr, OriState#vdritem.id, OriState#vdritem.serialno, OriState#vdritem.auth, Data]),
    % Update active time for VDR
    DateTime = {erlang:date(), erlang:time()},
    State = OriState#vdritem{acttime=DateTime},
    %State = OriState#vdritem{acttime=DateTime, vehicleid=1},
    %DataDebug = <<126,1,2,0,2,1,86,121,16,51,112,0,14,81,82,113,126>>,
    %DataDebug = <<126,1,2,0,2,1,86,121,16,51,112,44,40,81,82,123,126>>,
    %DataDebug = <<126,2,0,0,46,1,86,121,16,51,112,0,2,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,3,36,25,18,68,1,4,0,0,0,0,2,2,0,0,3,2,0,0,4,2,0,0,59,126>>,
    %DataDebug = <<126,2,0,0,46,1,86,121,16,51,112,3,44,0,8,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,3,36,35,85,35,1,4,0,0,0,0,2,2,0,0,3,2,0,0,4,2,0,0,4,126>>,
    Msgs = common:split_msg_to_single(Data, 16#7e),
    %Messages = common:split_msg_to_single(DataDebug, 16#7e),
    case Msgs of
        [] ->
            ErrCount = State#vdritem.errorcount + 1,
            common:loginfo("VDR (~p) data empty : continous error count is ~p (max is 3)~n", [State#vdritem.addr, ErrCount]),
            if
                ErrCount >= ?MAX_VDR_ERR_COUNT ->
                    {stop, vdrerror, State#vdritem{errorcount=ErrCount}};
                true ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, State#vdritem{errorcount=ErrCount}}
            end;    
        _ ->
            case process_vdr_msges(Socket, Msgs, State) of
                {error, vdrerror, NewState} ->
                    ErrCount = NewState#vdritem.errorcount + 1,
                    common:loginfo("VDR (~p) data error : continous count is ~p (max is 3)~n", [NewState#vdritem.addr, ErrCount]),
                    if
                        ErrCount >= ?MAX_VDR_ERR_COUNT ->
                            {stop, vdrerror, NewState#vdritem{errorcount=ErrCount}};
                        true ->
                            inet:setopts(Socket, [{active, once}]),
                            {noreply, NewState#vdritem{errorcount=ErrCount}}
                    end;
                {error, ErrType, NewState} ->
                    {stop, ErrType, NewState};
                {warning, NewState} ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, NewState#vdritem{errorcount=0}};
                {ok, NewState} ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, NewState#vdritem{errorcount=0}}
            end
    end;
handle_info({tcp_closed, _Socket}, State) ->    
    common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p) : tcp_closed~n", [State#vdritem.addr, State#vdritem.id, State#vdritem.serialno, State#vdritem.auth]),
	{stop, tcp_closed, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

%%%
%%% When VDR handler process is terminated, do the clean jobs here
%%%
terminate(Reason, State) ->
    common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p) starts being terminated : ~p~n", [State#vdritem.addr, State#vdritem.id, State#vdritem.serialno, State#vdritem.auth, Reason]),
    ID = State#vdritem.id,
    Auth = State#vdritem.auth,
    _SerialNo = State#vdritem.serialno,
    VehicleID = State#vdritem.vehicleid,
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
            ets:delete(vdridsocktable, ID)
    end,
    case VehicleID of
        undefined ->
            ok;
        _ ->
            {ok, WSUpdate} = wsock_data_parser:create_term_offline([VehicleID]),
            send_msg_to_ws(WSUpdate, State)
    end,
    case Auth of
        undefined ->
            ok;
        _ ->
            Sql = list_to_binary([<<"update device set is_online=0 where authen_code='">>, 
                                  list_to_binary(Auth), 
                                  <<"'">>]),
            send_sql_to_db(conn, Sql, State)
    end,
	try gen_tcp:close(State#vdritem.socket)
    catch
        _:Ex ->
            common:logerror("VDR (~p) : exception when gen_tcp:close : ~p~n", [State#vdritem.addr, Ex])
    end,
    common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p) is terminated~n", [State#vdritem.addr, State#vdritem.id, State#vdritem.serialno, State#vdritem.auth]).

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
%%% MsgIdx  : VDR message index
%%% FlowIdx : Gateway message flow index
%%%
process_vdr_data(Socket, Data, State) ->
    case vdr_data_parser:process_data(State, Data) of
        {ok, HeadInfo, Msg, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeadInfo,
            if
                State#vdritem.id == undefined ->
                    common:loginfo("Unknown VDR (~p) MSG ID : ~p~n", [NewState#vdritem.addr, ID]),
                    case ID of
                        16#100 ->
                            % Not complete
                            % Register VDR
                            %{Province, City, Producer, TermModel, TermID, LicColor, LicID} = Msg,
                            case create_sql_from_vdr(HeadInfo, Msg, State) of
                                {ok, Sql} ->
                                    SqlResp = send_sql_to_db(conn, Sql, State),
                                    % 0 : ok
                                    % 1 : vehicle registered
                                    % 2 : no such vehicle in DB
                                    % 3 : VDR registered
                                    % 4 : no such VDR in DB
                                    case extract_db_resp(SqlResp) of
                                        {ok, empty} ->
                                            FlowIdx = NewState#vdritem.msgflownum,
                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 4, empty),
                                            VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                                            common:loginfo("VDR (~p) response for 16#100 (no such VDR in DB) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                            send_data_to_vdr(Socket, VDRResp, NewState),
                                            
                                            % return error to terminate VDR connection
                                            {error, dberror, NewState#vdritem{msgflownum=FlowIdx+1}};
                                        {ok, [Rec]} ->
                                            % "id" is PK, so it cannot be null or undefined
                                            {<<"device">>, <<"id">>, DeviceID} = get_record_field(<<"device">>, Rec, <<"id">>),
                                            % "serial_no" is the query condition and NOT NULL & UNIQUE, so it cannot be null or undefined
                                            %{<<"device">>, <<"serial_no">>, SerialNo} = get_record_field(<<"device">>, Rec, <<"serial_no">>),
                                            {<<"device">>, <<"reg_time">>, VDRRegTime} = get_record_field(<<"device">>, Rec, <<"reg_time">>),
                                            if
                                                VDRRegTime == undefined ->
                                                    {Year, Month, Day} = erlang:date(),
                                                    {Hour, Minute, Second} = erlang:time(),
                                                    DateTime = integer_to_list(Year) ++ "-" ++ 
                                                                   integer_to_list(Month) ++ "-" ++ 
                                                                   integer_to_list(Day) ++ " " ++ 
                                                                   integer_to_list(Hour) ++ ":" ++ 
                                                                   integer_to_list(Minute) ++ ":" ++ 
                                                                   integer_to_list(Second),
                                                    VDRRegTimeSql = list_to_binary([<<"update device set reg_time='">>,
                                                                                    list_to_binary(DateTime),
                                                                                    <<"' where id=">>,
                                                                                    common:integer_to_binary(DeviceID)]),
                                                    % Should we check the update result?
                                                    send_sql_to_db(conn, VDRRegTimeSql, NewState),
                                                    
                                                    {_Province, _City, _Producer, _VDRModel, _VDRSerialNo, _LicColor, LicID} = Msg,
                                                    VehicleInfoSql = list_to_binary([<<"select * from vehicle where code='">>,
                                                                                    list_to_binary(LicID),
                                                                                    <<"'">>]),
                                                    VehicleInfoRes = send_sql_to_db(conn, VehicleInfoSql, NewState),
                                                    case extract_db_resp(VehicleInfoRes) of
                                                        {ok, empty} ->
                                                            FlowIdx = State#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 2, empty),
                                                            VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                                                            common:loginfo("VDR (~p) response for 16#100 (no such vehicle in DB) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                                            send_data_to_vdr(Socket, VDRResp, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=FlowIdx+1}};
                                                        {ok, [VehicleInfoRec]} ->
                                                            % "id" is PK, so it cannot be null or undefined
                                                            {<<"vehicle">>, <<"id">>, OriginalVehicleID} = get_record_field(<<"vehicle">>, VehicleInfoRec, <<"id">>),
                                                            % "code" is NOT NULL & UNIQUE, so it cannot be null or undefined
                                                            {<<"vehicle">>, <<"code">>, OriginalVehicleCode} = get_record_field(<<"vehicle">>, VehicleInfoRec, <<"code">>),
                                                            % It is from join query, so it can be undefined, however, it cannot be null
                                                            {<<"vehicle">>, <<"id">>, VehicleID} = get_record_field(<<"vehicle">>, Rec, <<"id">>),
                                                            % It is from join query, so it can be undefined, however, it cannot be null
                                                            {<<"vehicle">>, <<"code">>, VehicleCode} = get_record_field(<<"vehicle">>, Rec, <<"code">>),
                                                            if
                                                                VehicleID == undefined orelse VehicleCode == undefined orelse VehicleID =/= OriginalVehicleID orelse VehicleCode =/= OriginalVehicleCode ->
                                                                    FlowIdx = NewState#vdritem.msgflownum,
                                                                    MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 2, empty),
                                                                    VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                                                                    common:loginfo("VDR (~p) response for 16#100 (no such vehicle in DB) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                                                    send_data_to_vdr(Socket, VDRResp, NewState),
                                                                    
                                                                    % return error to terminate VDR connection
                                                                    {error, dberror, NewState#vdritem{msgflownum=FlowIdx+1}};
                                                                true ->
                                                                    {<<"vehicle">>, <<"dev_install_time">>, DevInstallTime} = get_record_field(<<"vehicle">>, Rec, <<"dev_install_time">>),
                                                                    if
                                                                        DevInstallTime == undefined ->
                                                                            UpdateDevInstallTimeSql = list_to_binary([<<"update vehicle set dev_install_time='">>,
                                                                                                                      list_to_binary(DateTime),
                                                                                                                      <<"' where device_id=">>,
                                                                                                                      common:integer_to_binary(DeviceID)]),
                                                                            % Should we check the update result?
                                                                            send_sql_to_db(conn, UpdateDevInstallTimeSql, NewState),
                                                                            
                                                                            {<<"device">>, <<"authen_code">>, AuthenCode} = get_record_field(<<"device">>, Rec, <<"authen_code">>),
                                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(AuthenCode)),
                                                                            VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                                                                            common:loginfo("VDR (~p) response for 16#100 (ok) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                                                            send_data_to_vdr(Socket, VDRResp, NewState),
                                                                            
                                                                            {ok, NewState#vdritem{msgflownum=FlowIdx+1, msg2vdr=[], msg=[], req=[]}};
                                                                        true ->
                                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 1, empty),
                                                                            VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                                                                            common:loginfo("VDR (~p) response for 16#100 (vehicle registered) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                                                            send_data_to_vdr(Socket, VDRResp, NewState),
                                                                            
                                                                            % return error to terminate VDR connection
                                                                            {error, dberror, NewState#vdritem{msgflownum=FlowIdx+1}}
                                                                    end
                                                             end;
                                                        _ ->
                                                            {error, dberror, NewState}
                                                    end;
                                                true ->
                                                    FlowIdx = NewState#vdritem.msgflownum,
                                                    MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 3, empty),
                                                    VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                                                    common:loginfo("VDR (~p) response for 16#100 (VDR registered) : ~p~n", [State#vdritem.addr, VDRResp]),
                                                    send_data_to_vdr(Socket, VDRResp, NewState),
                                                    
                                                    % return error to terminate VDR connection
                                                    {error, dberror, NewState#vdritem{msgflownum=FlowIdx+1}}
                                            end;
                                        _ ->
                                            % 
                                            {error, dberror, NewState}
                                    end;
                                _ ->
                                    {error, vdrerror, NewState}
                            end;
                        16#102 ->
                            % VDR Authentication
                            case create_sql_from_vdr(HeadInfo, Msg, State) of
                            %Sql = "select * from device,vehicle where device.serial_no='abcdef' and vehicle.device_id=device.id",
                            %case {ok, Sql} of
                                {ok, Sql} ->
                                    SqlResp = send_sql_to_db(conn, Sql, State),
                                    case extract_db_resp(SqlResp) of
                                        {ok, empty} ->
                                            {error, dberror, NewState};
                                        {ok, [Rec]} ->
                                            % "id" is PK, so it cannot be null or empty
                                            {<<"device">>, <<"id">>, VDRID} = get_record_field(<<"device">>, Rec, <<"id">>),
                                            % "serial" is NOT NULL & UNIQUE, so it cannot be null or undefined
                                            {<<"device">>, <<"serial_no">>, VDRSerialNo} = get_record_field(<<"device">>, Rec, <<"serial_no">>),
                                            % "authen_code" is NOT NULL & UNIQUE, so it cannot be null or undefined
                                            {<<"device">>, <<"authen_code">>, VDRAuthenCode} = get_record_field(<<"device">>, Rec, <<"authen_code">>),
                                            % "id" is PK, so it cannot be null. However it can be undefined because vehicle table device_id may don't be euqual to device table id 
                                            {<<"vehicle">>, <<"id">>, VehicleID} = get_record_field(<<"vehicle">>, Rec, <<"id">>),
                                            % "id" is NOT NULL & UNIQUE, so it cannot be null. However it can be undefined because vehicle table device_id may don't be euqual to device table id 
                                            {<<"vehicle">>, <<"code">>, VehicleCode} = get_record_field(<<"vehicle">>, Rec, <<"code">>),
                                            if
                                                VehicleID == undefined orelse VehicleCode==undefined ->
                                                    {error, dberror, State};
                                                true ->
                                                    % Not tested yet.
                                                    IDSockList = ets:lookup(vdridsocktable, VDRID),
                                                    disconn_socket_by_id(IDSockList),
                                                    SockVdrList = ets:lookup(vdrtable, Socket),
                                                    case length(SockVdrList) of
                                                        1 ->
                                                            % "authen_code" is the query condition, so Auth should be equal to VDRAuthEnCode
                                                            %{Auth} = Msg,
                                                            [SockVdr] = SockVdrList,
                                                            ets:insert(vdrtable, SockVdr#vdritem{id=VDRID, 
                                                                                                 serialno=binary_to_list(VDRSerialNo), 
                                                                                                 auth=binary_to_list(VDRAuthenCode),
                                                                                                 vehicleid=VehicleID,
                                                                                                 vehiclecode=binary_to_list(VehicleCode)}),
                                                            ets:insert(vdridsocktable, #vdridsockitem{id=VDRID, socket=Socket, addr=State#vdritem.addr}),
                                                            
                                                            SqlUpdate = list_to_binary([<<"update device set is_online=1 where authen_code='">>, VDRAuthenCode, <<"'">>]),
                                                            send_sql_to_db(conn, SqlUpdate, State),
                                                            
                                                            case wsock_data_parser:create_term_online([VehicleID]) of
                                                                {ok, WSUpdate} ->
                                                                    common:loginfo("VDR (~p) WS : ~p~n", [State#vdritem.addr, WSUpdate]),
                                                                    send_msg_to_ws(WSUpdate, State),
                                                                    %wsock_client:send(WSUpdate),
                                                            
                                                                    FlowIdx = NewState#vdritem.msgflownum,
                                                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                                                                    VDRResp = vdr_data_processor:create_final_msg(16#8001, FlowIdx, MsgBody),
                                                                    common:loginfo("VDR (~p) response for 16#102 (ok) : ~p~n", [State#vdritem.addr, VDRResp]),
                                                                    send_data_to_vdr(Socket, VDRResp, State),
                                        
                                                                    {ok, State#vdritem{id=VDRID, 
                                                                                       serialno=binary_to_list(VDRSerialNo),
                                                                                       auth=binary_to_list(VDRAuthenCode),
                                                                                       vehicleid=VehicleID,
                                                                                       vehiclecode=binary_to_list(VehicleCode),
                                                                                       msgflownum=FlowIdx+1, msg2vdr=[], msg=[], req=[]}};
                                                                _ ->
                                                                    {error, wserror, State}
                                                            end;
                                                        _ ->
                                                            % vdrtable or vdridsocktable error
                                                            {error, systemerror, State}
                                                    end
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
                    common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p) MSG ID : ~p~n", [NewState#vdritem.addr, NewState#vdritem.id, NewState#vdritem.serialno, NewState#vdritem.auth, ID]),
                    case ID of
                        16#1 ->     % VDR general response
                            {_GwFlowIdx, _GwID, _GwRes} = Msg,
                            
                            % Process reponse from VDR here

                            {ok, NewState};                      
                        16#2 ->     % VDR pulse
                            % Nothing to do here
                            %{} = Msg,
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            VDRResp = vdr_data_processor:create_final_msg(16#8100, FlowIdx, MsgBody),
                            common:loginfo("VDR (~p) response for 16#2 (Pulse) : ~p~n", [State#vdritem.addr, VDRResp]),
                            send_data_to_vdr(Socket, VDRResp, NewState),

                            {ok, NewState#vdritem{msgflownum=FlowIdx+1}};
                        16#3 ->     % VDR unregistration
                            %{} = Msg,
                            Auth = NewState#vdritem.auth,
                            ID = NewState#vdritem.id,
                            case create_sql_from_vdr(HeadInfo, {ID, Auth}, NewState) of
                                {ok, Sql} ->
                                    send_sql_to_db(conn, Sql, NewState),
        
                                    FlowIdx = NewState#vdritem.msgflownum,
                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                                    VDRResp = vdr_data_processor:create_final_msg(16#8001, FlowIdx, MsgBody),
                                    common:loginfo("VDR (~p) response for 16#3 (Position) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                    send_data_to_vdr(Socket, VDRResp, NewState),
        
                                    % return error to terminate connection with VDR
                                    {error, invaliderror, NewState#vdritem{msgflownum=FlowIdx+1}};
                                _ ->
                                    {error, invaliderror, NewState}
                            end;
                        16#104 ->   % VDR parameter query
                            {_RespIdx, _ActLen, _List} = Msg,
                            
                            % Process response from VDR here
                            
                            {ok, NewState};
                        16#107 ->   % VDR property query
                            {_Type, _ProId, _Model, _TerId, _ICCID, _HwVerLen, _HwVer, _FwVerLen, _FwVer, _GNSS, _Prop} = Msg,
                            
                            % Process response from VDR here

                            {ok, NewState};
                        16#108 ->
                            {_Type, _Res} = Msg,
                            
                            % Process response from VDR here
                            
                            {ok, NewState};
                        16#200 ->
                            case create_sql_from_vdr(HeadInfo, Msg, NewState) of
                                {ok, Sqls} ->
                                    %common:loginfo("VDR (~p) DB : ~p~n", [NewState#vdritem.addr, Sql]),
                                    send_sqls_to_db(conn, Sqls, NewState),
                                    
                                    FlowIdx = NewState#vdritem.msgflownum,
                                    %PreviousAlarm = NewState#vdritem.alarm,
                                    
                                    {H, _AppInfo} = Msg,
                                    [AlarmSym, _StateFlag, _Lat, _Lon, _Height, _Speed, _Direction, _Time]= H,
                                    %if
                                    %    AlarmSym == PreviousAlarm ->
                                    %        ok;
                                    %    true ->
                                    %        <<Year:8, Month:8, Day:8, Hour:8, Minute:8, Second:8>> = <<Time:48>>,
                                    %        YearS = common:integer_to_binary(common:convert_bcd_integer(Year)),
                                    %        MonthS = common:integer_to_binary(common:convert_bcd_integer(Month)),
                                    %        DayS = common:integer_to_binary(common:convert_bcd_integer(Day)),
                                    %        HourS = common:integer_to_binary(common:convert_bcd_integer(Hour)),
                                    %        MinuteS = common:integer_to_binary(common:convert_bcd_integer(Minute)),
                                    %        SecondS = common:integer_to_binary(common:convert_bcd_integer(Second)),
                                    %        TimeS = list_to_binary([YearS, <<"-">>, MonthS, <<"-">>, DayS, <<" ">>, HourS, <<":">>, MinuteS, <<":">>, SecondS]),
                                    %        {ok, WSUpdate} = wsock_data_parser:create_term_alarm([NewState#vdritem.vehicleid],
                                    %                                                             FlowIdx,
                                    %                                                             NewState#vdritem.vehiclecode,
                                    %                                                             AlarmSym, StateFlag,
                                    %                                                             Lat, Lon,
                                    %                                                             binary_to_list(TimeS)),
                                    %        common:loginfo("VDR (~p) WS : ~p~n", [NewState#vdritem.addr, WSUpdate]),
                                    %        send_msg_to_ws(WSUpdate, NewState)
                                    %        %wsock_client:send(WSUpdate)
                                    %end,
        
                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                                    VDRResp = vdr_data_processor:create_final_msg(16#8001, FlowIdx, MsgBody),
                                    common:loginfo("VDR (~p) response for 16#200 (ok) : ~p~n", [NewState#vdritem.addr, VDRResp]),
                                    send_data_to_vdr(Socket, VDRResp, NewState),
                                    
                                    {ok, NewState#vdritem{msgflownum=FlowIdx+1, alarm=AlarmSym}};
                                _ ->
                                    {error, invaliderror, NewState}
                            end;
                        16#201 ->
                            {_RespNum, _PosMsg} = Msg,
            
                            {ok, NewState};
                        16#301 ->
                            {_Id} = Msg,
                            
                            {ok, NewState};
                        16#302 ->
                            {_Id} = Msg,
                            
                            {ok, NewState};
                        16#303 ->
                            {_MsgType, _POC} = Msg,
                            
                            {ok, NewState};
                        16#500 ->
                            {_FlowNum, _Resp} = Msg,
                            
                            {ok, NewState};
                        16#700 ->
                            {_Number, _OrderWord, _DB} = Msg,
                            
                            {ok, NewState};
                        16#701 ->
                            {_Length, _Content} = Msg,
                            
                            {ok, NewState};
                        16#702 ->
                            {_DrvState, _Time, _IcReadResult, _NameLen, _N, _CerNum, _OrgLen, _O, _Validity} = Msg,
                            
                            {ok, NewState};
                        16#704 ->
                            {_Len, _Type, _Positions} = Msg,
                            
                            {ok, NewState};
                        16#705 ->
                            {_Count, _Time, _Data} = Msg,
                            
                            {ok, NewState};
                        16#800 ->
                            {_Id, _Type, _Code, _EICode, _PipeId} = Msg,
                            
                            {ok, NewState};
                        16#801 ->
                            {_Id, _Type, _Code, _EICode, _PipeId, _MsgBody, _Pack} = Msg,
                            
                            {ok, NewState};
                        16#805 ->
                            {_RespIdx, _Res, _ActLen, _List} = Msg,
                            
                            {ok, NewState};
                        16#802 ->
                            {_FlowNum, _Len, _RespData} = Msg,
                            
                            {ok, NewState};
                        16#900 ->
                            {_Type, _Con} = Msg,
                            
                            {ok, NewState};
                        16#901 ->
                            {_Len, _Body} = Msg,
                            
                            {ok, NewState};
                        16#A00 ->
                            {_E, _N} = Msg,
                            
                            {ok, NewState};
                        _ ->
                            {ok, NewState}
                    end
            end;
        {ignore, HeaderInfo, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
            VDRResp = vdr_data_processor:create_final_msg(16#8001, FlowIdx, MsgBody),
            send_data_to_vdr(Socket, VDRResp, NewState),
            
            {ok, NewState#vdritem{msgflownum=FlowIdx+1}};
        {warning, HeaderInfo, ErrorType, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ErrorType),
            VDRResp = vdr_data_processor:create_final_msg(16#8001, FlowIdx, MsgBody),
            send_data_to_vdr(Socket, VDRResp, NewState),
            
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
%send_resp_to_vdr(RespType, Socket, VDRMsgID, VDRMsgIdx, FlowIdx, Type) ->
%    if
%        Type =/= ?T_GEN_RESP_OK andalso Type =/= ?T_GEN_RESP_FAIL andalso Type =/= ?T_GEN_RESP_ERRMSG andalso Type =/= ?T_GEN_RESP_NOTSUPPORT ->
%            ok;
%        true ->
%            MsgBody = vdr_data_processor:create_gen_resp(VDRMsgID, VDRMsgIdx, Type),
%            VDRResp = vdr_data_processor:create_final_msg(RespType, FlowIdx, MsgBody),
%            send_data_to_vdr(Socket, VDRResp)
%    end.

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
send_data_to_vdr(Socket, Msg, _State) ->
    gen_tcp:send(Socket, Msg).
    %gen_server:cast(?MODULE, {send, Socket, Msg}).

%%%
%%%
%%%
send_sql_to_db(PoolId, Msg, State) ->
    %mysql:fetch(PoolId, Msg).
    %gen_server:call(?MODULE, {fetch, PoolId, Msg}).
    case State#vdritem.dbpid of
        undefined ->
            ok;
        DBPid ->
            DBPid ! {State#vdritem.pid, PoolId, Msg},
            Pid = State#vdritem.pid,
            receive
                {Pid, Result} ->
                    Result
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_sqls_to_db(PoolId, Msgs, State) ->
    %mysql:fetch(PoolId, Msg).
    %gen_server:call(?MODULE, {fetch, PoolId, Msg}).
    case Msgs of
        [] ->
            ok;
        _ ->
            [H|T] = Msgs,
            case State#vdritem.dbpid of
                undefined ->
                    ok;
                DBPid ->
                    DBPid ! {State#vdritem.pid, PoolId, H},
                    Pid = State#vdritem.pid,
                    receive
                        {Pid, Result} ->
                            Result
                    end,
                    case T of
                        [] ->
                            ok;
                        _ ->
                            send_sqls_to_db(PoolId, T, State)
                    end
            end
    end.

%%%
%%%
%%%
send_msg_to_ws(Msg, State) ->
    %wsock_client:send(Msg).
    %gen_server:call(?MODULE, {fetch, PoolId, Msg}).
    case State#vdritem.wspid of
        undefined ->
            ok;
        WSPid ->
            WSPid ! {State#vdritem.pid, Msg},
            Pid = State#vdritem.pid,
            receive
                {Pid, wsok} ->
                    ok
            end
    end.
    

%%%         
%%% Return :
%%%     {ok, SQL|[SQL0, SQL1, ...]}
%%%     {error, iderror}
%%%     error
%%%
create_sql_from_vdr(HeaderInfo, Msg, State) ->
    {ID, _FlowNum, _TelNum, _CryptoType} = HeaderInfo,
    case ID of
        16#1    ->
            {ok, ""};
        16#2    ->                          
            {ok, ""};
        16#100  ->          % Not complete, currently only use VDRSerialNo for query                     
            {_Province, _City, _Producer, _VDRModel, VDRSerialNo, _LicColor, _LicID} = Msg,
            SQL = list_to_binary([<<"select * from device left join vehicle on vehicle.device_id=device.id where device.serial_no='">>,
                                  list_to_binary(VDRSerialNo), <<"'">>]),
            {ok, SQL};
        16#3    ->                          
            {ID, Auth} = Msg,
            {ok, list_to_binary([<<"update device set reg_time=null where authen_code='">>, list_to_binary(Auth), <<"' or id='">>, list_to_binary(ID), <<"'">>])};
        16#102  ->
            {Auth} = Msg,
            {ok, list_to_binary([<<"select * from device left join vehicle on vehicle.device_id=device.id where device.authen_code='">>, list_to_binary(Auth), <<"'">>])};
        16#104  ->
            {_RespIdx, _ActLen, _List} = Msg,
            {ok, ""};
        16#107  ->
            {_Type, _ProId, _Model, _TerId, _ICCID, _HwVerLen, _HwVer, _FwVerLen, _FwVer, _GNSS, _Prop} = Msg,
            {ok, ""};
        16#108  ->    
            {_Type, _Res} = Msg,
            {ok, ""};
        16#200  ->
            case Msg of
                {H} ->
                    [AlarmSym, StateFlag, Lat, Lon, Height, Speed, Direction, Time]= H,
                    <<YY:8, MMon:8, DD:8, HH:8, MMin:8, SS:8>> = <<Time:48>>,
                    Year = common:convert_bcd_integer(YY),
                    Month = common:convert_bcd_integer(MMon),
                    Day = common:convert_bcd_integer(DD),
                    Hour = common:convert_bcd_integer(HH),
                    Minute = common:convert_bcd_integer(MMin),
                    Second = common:convert_bcd_integer(SS),
                    {ServerYear, ServerMonth, ServerDay} = erlang:date(),
                    {ServerHour, ServerMinute, ServerSecond} = erlang:time(),
                    YearS = common:integer_to_binary(Year),
                    MonthS = common:integer_to_binary(Month),
                    DayS = common:integer_to_binary(Day),
                    HourS = common:integer_to_binary(Hour),
                    MinuteS = common:integer_to_binary(Minute),
                    SecondS = common:integer_to_binary(Second),
                    {ServerYear, ServerMonth, ServerDay} = erlang:date(),
                    {ServerHour, ServerMinute, ServerSecond} = erlang:time(),
                    YearS = common:integer_to_binary(Year),
                    MonthS = common:integer_to_binary(Month),
                    DayS = common:integer_to_binary(Day),
                    HourS = common:integer_to_binary(Hour),
                    MinuteS = common:integer_to_binary(Minute),
                    SecondS = common:integer_to_binary(Second),
                    TimeS = list_to_binary([YearS, <<"-">>, MonthS, <<"-">>, DayS, <<" ">>, HourS, <<":">>, MinuteS, <<":">>, SecondS]),
                    ServerYearS = common:integer_to_binary(ServerYear),
                    ServerMonthS = common:integer_to_binary(ServerMonth),
                    ServerDayS = common:integer_to_binary(ServerDay),
                    ServerHourS = common:integer_to_binary(ServerHour),
                    ServerMinuteS = common:integer_to_binary(ServerMinute),
                    ServerSecondS = common:integer_to_binary(ServerSecond),
                    ServerTimeS = list_to_binary([ServerYearS, <<"-">>, ServerMonthS, <<"-">>, ServerDayS, <<" ">>, ServerHourS, <<":">>, ServerMinuteS, <<":">>, ServerSecondS]),
                    VehicleID = State#vdritem.vehicleid,
                    SQL0 = list_to_binary([<<"insert into vehicle_position(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:integer_to_binary(Lon), <<", ">>,
                                          common:integer_to_binary(Lat), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:integer_to_binary(Speed), <<", ">>,
                                          common:integer_to_binary(Direction), <<", ">>,
                                          common:integer_to_binary(StateFlag), <<", ">>,
                                          common:integer_to_binary(AlarmSym), <<")">>]),
                    SQL1 = list_to_binary([<<"replace into vehicle_position_last(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:integer_to_binary(Lon), <<", ">>,
                                          common:integer_to_binary(Lat), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:integer_to_binary(Speed), <<", ">>,
                                          common:integer_to_binary(Direction), <<", ">>,
                                          common:integer_to_binary(StateFlag), <<", ">>,
                                          common:integer_to_binary(AlarmSym), <<")">>]),
                    {ok, [SQL0, SQL1]};
                {H, AppInfo} ->
                    [AlarmSym, StateFlag, Lat, Lon, Height, Speed, Direction, Time]= H,
                    AppInfo,
                    <<YY:8, MMon:8, DD:8, HH:8, MMin:8, SS:8>> = <<Time:48>>,
                    Year = common:convert_bcd_integer(YY),
                    Month = common:convert_bcd_integer(MMon),
                    Day = common:convert_bcd_integer(DD),
                    Hour = common:convert_bcd_integer(HH),
                    Minute = common:convert_bcd_integer(MMin),
                    Second = common:convert_bcd_integer(SS),
                    {ServerYear, ServerMonth, ServerDay} = erlang:date(),
                    {ServerHour, ServerMinute, ServerSecond} = erlang:time(),
                    YearS = common:integer_to_binary(Year),
                    MonthS = common:integer_to_binary(Month),
                    DayS = common:integer_to_binary(Day),
                    HourS = common:integer_to_binary(Hour),
                    MinuteS = common:integer_to_binary(Minute),
                    SecondS = common:integer_to_binary(Second),
                    TimeS = list_to_binary([YearS, <<"-">>, MonthS, <<"-">>, DayS, <<" ">>, HourS, <<":">>, MinuteS, <<":">>, SecondS]),
                    ServerYearS = common:integer_to_binary(ServerYear),
                    ServerMonthS = common:integer_to_binary(ServerMonth),
                    ServerDayS = common:integer_to_binary(ServerDay),
                    ServerHourS = common:integer_to_binary(ServerHour),
                    ServerMinuteS = common:integer_to_binary(ServerMinute),
                    ServerSecondS = common:integer_to_binary(ServerSecond),
                    ServerTimeS = list_to_binary([ServerYearS, <<"-">>, ServerMonthS, <<"-">>, ServerDayS, <<" ">>, ServerHourS, <<":">>, ServerMinuteS, <<":">>, ServerSecondS]),
                    VehicleID = State#vdritem.vehicleid,
                    SQL0 = list_to_binary([<<"insert into vehicle_position(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:integer_to_binary(Lon), <<", ">>,
                                          common:integer_to_binary(Lat), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:integer_to_binary(Speed), <<", ">>,
                                          common:integer_to_binary(Direction), <<", ">>,
                                          common:integer_to_binary(StateFlag), <<", ">>,
                                          common:integer_to_binary(AlarmSym), <<")">>]),
                    SQL1 = list_to_binary([<<"replace into vehicle_position_last(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:integer_to_binary(Lon), <<", ">>,
                                          common:integer_to_binary(Lat), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:integer_to_binary(Speed), <<", ">>,
                                          common:integer_to_binary(Direction), <<", ">>,
                                          common:integer_to_binary(StateFlag), <<", ">>,
                                          common:integer_to_binary(AlarmSym), <<")">>]),
                    {ok, [SQL0, SQL1]}
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
                    {Tab, ColName, _Len, _Type} = H1,
                    case T1 of
                        [] ->
                            [{Tab, ColName, H2}];
                        _ ->
                            [{Tab, ColName, H2}|compose_db_resp_record(T1, T2)]
                    end
            end;
        true ->
            error
    end.

%%%
%%% The caller should make sure of Record is not empty, which is not []
%%%
%%% Return  :
%%%     null        : Cannot find this field in the response of SQL, which may mean DB table error
%%%     undefined   : NULL in DB
%%%
get_record_field(Table, Record, Field) ->
    [H|T] = Record,
    {Tab, Key, Value} = H,
    if
        Table == Tab andalso Key == Field ->
            {Tab, Key, Value};
        true ->
            case T of
                [] ->
                    {Tab, Key, null};
                _ ->
                    get_record_field(Table, T, Field)
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
%                            common:logerror("Data2VDR process : message type error unknown PID ~p : ~p~n", [FromPid, Res])
%                    end;
%                FromPid =/= Pid ->
%                    common:logerror("Data2VDR process : message from unknown PID ~p : ~p~n", [FromPid, Data])
%            end,        
%            data2vdr_process(Pid, Socket);
%        {FromPid, {data, Data}} ->
%            if 
%                FromPid == Pid ->
%                    gen_tcp:send(Socket, Data);
%                FromPid =/= Pid ->
%                    common:logerror("VDR server send data to VDR process : message from unknown PID ~p : ~p~n", [FromPid, Data])
%            end,        
%            data2vdr_process(Pid, Socket);
%        {FromPid, Data} ->
%            common:logerror("VDR server send data to VDR process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
%            data2vdr_process(Pid, Socket);
%        stop ->
%            ok
%    after ?TIMEOUT_DATA_VDR ->
%        %common:loginfo("VDR server send data to VDR process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
%        data2vdr_process(Pid, Socket)
%    end.

%%%
%%% Compose body, header and parity
%%% Calculate XOR value
%%% 0x7d -> 0x7d0x1 & 0x7e -> 0x7d0x2
%%%
%%% return {Response, NewState}
%%%
%createresp(HeaderInfo, Result, State) ->
%    {ID, FlowNum, TelNum, CryptoType} = HeaderInfo,
%    RespFlowNum = State#vdritem.msgflownum,
%    Body = <<FlowNum:16, ID:16, Result:8>>,
%    BodyLen = bit_size(Body),
%    BodyProp = <<0:2, 0:1, CryptoType:3, BodyLen:10>>,
%    Header = <<128, 1, BodyProp:16, TelNum:48, RespFlowNum:16>>,
%    HeaderBody = <<Header, Body>>,
%    XOR = vdr_data_parser:bxorbytelist(HeaderBody),
%    RawData = binary:replace(<<HeaderBody, XOR>>, <<125>>, <<125,1>>, [global]),
%    RawDataNew = binary:replace(RawData, <<126>>, <<125,2>>, [global]),
%    {<<126, RawDataNew, 126>>, State#vdritem{msgflownum=RespFlowNum+1}}.


