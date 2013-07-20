-module(vdr_handler).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([process_vdr_data/3,
         send_data_to_vdr/4]).

-include("header.hrl").
-include("mysql.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Sock, Addr]) ->
    process_flag(trap_exit, true),
    Pid = self(),
    VDRPid = spawn(fun() -> data2vdr_process(Sock) end),
    RespWSPid = spawn(fun() -> resp2ws_process([]) end),
    VdrMsgMonitorPid = spawn(fun() -> vdr_msg_monitor_process(Pid, Sock) end),
    [{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
    [{wspid, WSPid}] = ets:lookup(msgservertable, wspid),
    State = #vdritem{socket=Sock, pid=Pid, vdrpid=VDRPid, respwspid=RespWSPid, addr=Addr, msgflownum=1, errorcount=0, dbpid=DBPid, wspid=WSPid, vdrmsgtimeoutpid=VdrMsgMonitorPid},
	%mysql:fetch(regauth, <<"set names 'utf8'">>),
	mysql:fetch(conn, <<"set names 'utf8'">>),
	%mysql:fetch(cmd, <<"set names 'utf8'">>),
    ets:insert(vdrtable, State), 
    inet:setopts(Sock, [{active, once}]),
	{ok, State}.

%handle_call({fetch, PoolId, Msg}, _From, State) ->
%    Resp = mysql:fetch(PoolId, Msg),
%    {noreply, {ok, Resp}, State};
handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

%handle_cast({send, Socket, Msg}, State) ->
%    gen_tcp:send(Socket, Msg),
%    {noreply, State};
handle_cast(_Msg, State) ->    
	{noreply, State}. 

%%%
%%%
%%%
handle_info({tcp, Socket, Data}, OriState) ->
    common:loginfo("Data from VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~n~p~n",
				   [OriState#vdritem.addr, 
					OriState#vdritem.id, 
					OriState#vdritem.serialno, 
					OriState#vdritem.auth, 
					OriState#vdritem.vehicleid, 
					OriState#vdritem.vehiclecode,
					Data]),
    % Update active time for VDR
    DateTime = {erlang:date(), erlang:time()},
    State = OriState#vdritem{acttime=DateTime},
    %State = OriState#vdritem{acttime=DateTime, vehicleid=1},
    %DataDebug = <<126,1,2,0,2,1,86,121,16,51,112,0,14,81,82,113,126>>,
    %DataDebug = <<126,1,2,0,2,1,86,121,16,51,112,44,40,81,82,123,126>>,
    %DataDebug = <<126,2,0,0,46,1,86,121,16,51,112,0,2,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,3,36,25,18,68,1,4,0,0,0,0,2,2,0,0,3,2,0,0,4,2,0,0,59,126>>,
    %DataDebug = <<126,2,0,0,46,1,86,121,16,51,112,3,44,0,8,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,3,36,35,85,35,1,4,0,0,0,0,2,2,0,0,3,2,0,0,4,2,0,0,4,126>>,
	%DataDebug = <<126,1,0,0,45,1,86,0,71,2,5,0,55,0,11,0,114,55,48,51,49,57,74,76,57,48,49,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,48,52,55,48,50,48,53,1,190,169,66,55,48,50,48,53,39,126>>,
	%DataDebug = <<126,2,0,0,49,1,86,151,146,84,84,0,115,0,0,0,0,0,0,0,3,2,97,110,120,6,239,82,248,0,47,0,30,0,253,19,7,4,19,86,18,1,4,0,0,0,125,1,2,2,0,0,3,2,0,0,4,2,0,0,17,1,0,195,126>>,
	%DataDebug = <<126,8,0,0,8,1,52,1,8,18,33,46,94,81,234,104,178,1,3,0,0,28,126>>,
    Msgs = common:split_msg_to_single(Data, 16#7e),
    %Msgs = common:split_msg_to_single(DataDebug, 16#7e),
	%SqlAlarmList = list_to_binary([<<"select * from vehicle_alarm where vehicle_id=2215 and isnull(clear_time)">>]),
	%DBAlarmListResp = send_sql_to_db(conn, SqlAlarmList, State),
	%{ok, DBAlarmList} = extract_db_resp(DBAlarmListResp),
	%AlarmList = get_alarm_list(DBAlarmList),
	%common:loginfo("Original AlarmList : ~p~n", [AlarmList]),
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
    common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) : tcp_closed~n",
				   [State#vdritem.addr, 
					State#vdritem.id, 
					State#vdritem.serialno, 
					State#vdritem.auth,
					State#vdritem.vehicleid, 
					State#vdritem.vehiclecode]), 
	{stop, tcp_closed, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

%%%
%%% When VDR handler process is terminated, do the clean jobs here
%%%
terminate(Reason, State) ->
    common:loginfo("VDR (~p) socket (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) starts being terminated~nReason : ~p~n", 
				   [State#vdritem.addr,
					State#vdritem.socket,
					State#vdritem.id, 
					State#vdritem.serialno, 
					State#vdritem.auth, 
					State#vdritem.vehicleid, 
					State#vdritem.vehiclecode, 
					Reason]),
    %ID = State#vdritem.id,
    Auth = State#vdritem.auth,
    _SerialNo = State#vdritem.serialno,
    VehicleID = State#vdritem.vehicleid,
    Socket = State#vdritem.socket,
    VDRPid = State#vdritem.vdrpid,
	VDRMsgTimeoutPid = State#vdritem.vdrmsgtimeoutpid,
	Pid = self(),
    case VDRPid of
        undefined ->
            ok;
        _ ->
            VDRPid ! {Pid, stop},
			receive
				{Pid, stopped} ->
					ok
			after ?TIME_TERMINATE_VDR ->
					ok
			end
    end,
	case VDRMsgTimeoutPid of
		undefined ->
			ok;
		_ ->
			VDRMsgTimeoutPid ! {Pid, stop},
			receive
				{Pid, stopped} ->
					ok
			after ?TIME_TERMINATE_VDR ->
					ok
			end
	end,
    case Socket of
        undefined ->
            ok;
        _ ->
            ets:delete(vdrtable, Socket)
    end,
    case VehicleID of
        undefined ->
            ok;
        _ ->
            {ok, WSUpdate} = wsock_data_parser:create_term_offline([VehicleID]),
            common:loginfo("~p~n~p~n", [WSUpdate, list_to_binary(WSUpdate)]),
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
    common:loginfo("VDR (~p) : gen_tcp:close~n", [State#vdritem.addr]),
	try gen_tcp:close(State#vdritem.socket)
    catch
        _:Ex ->
            common:logerror("VDR (~p) : exception when gen_tcp:close : ~p~n", [State#vdritem.addr, Ex])
    end,
    common:loginfo("VDR (~p) socket (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) is terminated~n",
				   [State#vdritem.addr,
					State#vdritem.socket,
					State#vdritem.id, 
					State#vdritem.serialno, 
					State#vdritem.auth, 
					State#vdritem.vehicleid, 
					State#vdritem.vehiclecode]).

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
	VdrMsgTimeoutPid = State#vdritem.vdrmsgtimeoutpid,
	SelfPid = self(),
	VdrMsgTimeoutPid ! {SelfPid, Socket},
	receive
		{SelfPid, ok} ->
			do_process_vdr_data(Socket, Data, State)
	after ?VDR_MSG_RESP_TIMEOUT ->
		{error, systemerror, State}
	end.

do_process_vdr_data(Socket, Data, State) ->
	VDRPid = State#vdritem.vdrpid,
    case vdr_data_parser:process_data(State, Data) of
        {ok, HeadInfo, Msg, NewState} ->
            {ID, MsgIdx, Tel, _CryptoType} = HeadInfo,
            if
                State#vdritem.id == undefined ->
            		common:loginfo("Unknown VDR (~p) MSG ID (~p), MSG Index (~p), MSG Tel (~p)~n", [NewState#vdritem.addr, ID, MsgIdx, Tel]),
                    case ID of
                        16#100 ->
                            % Not complete
                            % Register VDR
                            %{Province, City, Producer, TermModel, TermID, LicColor, LicID} = Msg,
                            case create_sql_from_vdr(HeadInfo, Msg, State) of
                                {ok, Sql} ->
                                    %SqlResp = send_sql_to_db(regauth, Sql, State),
                                    SqlResp = send_sql_to_db(conn, Sql, State),
                                    % 0 : ok
                                    % 1 : vehicle registered
                                    % 2 : no such vehicle in DB
                                    % 3 : VDR registered
                                    % 4 : no such VDR in DB
                                    case extract_db_resp(SqlResp) of
                                        {ok, empty} -> % No vehicle and no VDR. However, only reply no vehicle here.
                                            FlowIdx = NewState#vdritem.msgflownum,
                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 2, empty),
                                            common:loginfo("~p sends VDR (~p) registration response (no such vechile in DB) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                            
                                            % return error to terminate VDR connection
                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                        {ok, [Rec]} ->
                                            % "id" is PK, so it cannot be null or undefined
                                            {<<"device">>, <<"id">>, DeviceID} = get_record_field(<<"device">>, Rec, <<"id">>),
                                            % "serial_no" is the query condition and NOT NULL & UNIQUE, so it cannot be null or undefined
                                            %{<<"device">>, <<"serial_no">>, DeviceSerialNo} = get_record_field(<<"device">>, Rec, <<"serial_no">>),
                                            {<<"device">>, <<"authen_code">>, DeviceAuthenCode} = get_record_field(<<"device">>, Rec, <<"authen_code">>),
                                            {<<"device">>, <<"vehicle_id">>, DeviceVehicleID} = get_record_field(<<"device">>, Rec, <<"vehicle_id">>),
                                            {<<"device">>, <<"reg_time">>, DeviceRegTime} = get_record_field(<<"device">>, Rec, <<"reg_time">>),
                                            % "id" is PK, so it cannot be null or undefined
                                            {<<"vehicle">>, <<"id">>, VehicleID} = get_record_field(<<"vehicle">>, Rec, <<"id">>),
                                            % "code" is the query condition and NOT NULL & UNIQUE, so it cannot be null or undefined
                                            {<<"vehicle">>, <<"code">>, VehicleCode} = get_record_field(<<"vehicle">>, Rec, <<"code">>),
                                            {<<"vehicle">>, <<"device_id">>, VehicleDeviceID} = get_record_field(<<"vehicle">>, Rec, <<"device_id">>),
                                            {<<"vehicle">>, <<"dev_install_time">>, VehicleDeviceInstallTime} = get_record_field(<<"vehicle">>, Rec, <<"dev_install_time">>),
                                            if
                                                VehicleID == undefined orelse DeviceID == undefined -> % No vehicle or no VDR
                                                    if
                                                        VehicleID == undefined ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 2, empty),
                                                            common:loginfo("~p sends VDR (~p) registration response (no such vechile in DB) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true -> % DeviceID == undefined ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 4, empty),
                                                            common:loginfo("~p sends VDR (~p) registration response (no such VDR in DB) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}}
                                                    end;
                                                VehicleDeviceID =/= undefined andalso DeviceVehicleID =/= undefined -> % Vehicle registered and VDR registered
                                                    if
                                                        VehicleDeviceID =/= DeviceID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 1, empty),
                                                            common:loginfo("~p sends VDR (~p) registration response (vehicle registered) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        DeviceVehicleID =/= VehicleID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 3, empty),
                                                            common:loginfo("~p sends VDR (~p) registration response (VDR registered) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
															case is_binary(DeviceAuthenCode) of
																true ->
		                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, DeviceAuthenCode),
		                                                            common:loginfo("~p sends VDR registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, VehicleCode, MsgBody]),
		                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
		                                                            
		                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        
		                                                            
		                                                            % return error to terminate VDR connection
		                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[]}};
																false ->
		                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
		                                                            common:loginfo("~p sends VDR registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, VehicleCode, MsgBody]),
		                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
		                                                            
		                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        
		                                                            
		                                                            % return error to terminate VDR connection
		                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[]}}
															end
                                                    end;
                                                VehicleDeviceID =/= undefined andalso DeviceVehicleID == undefined -> % Vehicle registered
                                                    if
                                                        VehicleDeviceID =/= DeviceID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 1, empty),
                                                            common:loginfo("~p sends VDR (~p) registration response (vehicle registered) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true ->
                                                            VDRVehicleIDSql = list_to_binary([<<"update device set vehicle_id='">>,
                                                                                              common:integer_to_binary(VehicleID),
                                                                                              <<"' where id=">>,
                                                                                              common:integer_to_binary(DeviceID)]),
                                                            % Should we check the update result?
                                                            send_sql_to_db(conn, VDRVehicleIDSql, NewState),
                                                            
                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        

                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
                                                            common:loginfo("~p sends VDR (~p) registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, VehicleCode, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[]}}
                                                    end;
                                                VehicleDeviceID == undefined andalso DeviceVehicleID =/= undefined -> % Vehicle registered
                                                    if
                                                        DeviceVehicleID =/= VehicleID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 3, empty),
                                                            common:loginfo("~p sends VDR (~p) registration response (VDR registered) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, dberror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true ->
                                                            VehicleVDRIDSql = list_to_binary([<<"update vehicle set device_id='">>,
                                                                                              common:integer_to_binary(DeviceID),
                                                                                              <<"' where id=">>,
                                                                                              common:integer_to_binary(VehicleID)]),
                                                            % Should we check the update result?
                                                            %send_sql_to_db(regauth, VehicleVDRIDSql, NewState),
                                                            send_sql_to_db(conn, VehicleVDRIDSql, NewState),
                                                            
                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        

                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
                                                            common:loginfo("~p sends VDR (~p) registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, VehicleCode, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),

                                                            % return error to terminate VDR connection
                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[]}}
                                                    end;
                                                VehicleDeviceID == undefined andalso DeviceVehicleID == undefined ->
                                                    VDRVehicleIDSql = list_to_binary([<<"update device set vehicle_id='">>,
                                                                                      common:integer_to_binary(VehicleID),
                                                                                      <<"' where id=">>,
                                                                                      common:integer_to_binary(DeviceID)]),
                                                    % Should we check the update result?
                                                    %send_sql_to_db(regauth, VDRVehicleIDSql, NewState),
                                                    send_sql_to_db(conn, VDRVehicleIDSql, NewState),
                                                    
                                                    VehicleVDRIDSql = list_to_binary([<<"update vehicle set device_id='">>,
                                                                                      common:integer_to_binary(DeviceID),
                                                                                      <<"' where id=">>,
                                                                                      common:integer_to_binary(VehicleID)]),
                                                    % Should we check the update result?
                                                    %send_sql_to_db(regauth, VehicleVDRIDSql, NewState),
                                                    send_sql_to_db(conn, VehicleVDRIDSql, NewState),

                                                    update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),      

                                                    FlowIdx = NewState#vdritem.msgflownum,
                                                    MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
                                                    common:loginfo("~p sends VDR (~p) registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, VehicleCode, MsgBody]),
                                                    NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),
                                                    
                                                    {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[]}};
                                                true -> % Impossible condition
                                                    {error, dberror, NewState}
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
                                    %SqlResp = send_sql_to_db(regauth, Sql, State),
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
                                            {<<"vehicle">>, <<"driver_id">>, DriverID} = get_record_field(<<"vehicle">>, Rec, <<"driver_id">>),
                                            if
                                                VehicleID == undefined orelse VehicleCode==undefined ->
                                                    {error, dberror, State};
                                                true ->
                                                    % Not tested yet.
													%VDRList = ets:match(vdrtable, '$1'),
													%common:loginfo("VDR table : all vdritems before disconnection : ~p~n", [VDRList]),
													SockList0 = ets:match(vdrtable, {'_', 
                                                                                     '$1', '_', '_', '_', VehicleID,
                                                                                     '_', '_', '_', '_', '_',
                                                                                     '_', '_', '_', '_', '_',
                                                                                     '_', '_', '_', '_', '_',
                                                                                     '_', '_', '_', '_', '_', '_', '_', '_'}),
													%common:loginfo("VDR table : sockets for VehicleID ~p before disconnection : ~p~n", [VehicleID, SockList0]),
                                                    disconn_socket_by_id(SockList0),
													%SockList1 = ets:match(vdrtable, {'_', 
                                                    %                                 '$1', '_', '_', '_', undefined,
                                                    %                                 '_', '_', '_', '_', '_',
                                                    %                                 '_', '_', '_', '_', '_',
                                                    %                                 '_', '_', '_', '_', '_',
                                                    %                                 '_', '_', '_', '_', '_', '_', '_', '_'}),
													%%common:loginfo("VDR table : current socket : ~p~nVDR table : sockets for VehicleID undefined before disconnection : ~p~n", [Socket, SockList1]),
                                                    %disconn_socket_by_id(SockList1, Socket),
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
                                                                                                 vehiclecode=binary_to_list(VehicleCode),
                                                                                                 driverid=DriverID}),
                                                            
                                                            SqlUpdate = list_to_binary([<<"update device set is_online=1 where authen_code='">>, VDRAuthenCode, <<"'">>]),
                                                            %send_sql_to_db(regauth, SqlUpdate, State),
                                                            send_sql_to_db(conn, SqlUpdate, State),
															
															SqlAlarmList = list_to_binary([<<"select * from vehicle_alarm where vehicle_id=">>, common:integer_to_binary(VehicleID), <<" and isnull(clear_time)">>]),
															SqlAlarmListResp = send_sql_to_db(conn, SqlAlarmList, State),
															case extract_db_resp(SqlAlarmListResp) of
																{ok, empty} ->
																	common:loginfo("Original AlarmList : []~n"),	
		                                                            case wsock_data_parser:create_term_online([VehicleID]) of
		                                                                {ok, WSUpdate} ->
		                                                                    common:loginfo("VDR (~p) WS : ~p~n~p~n", [State#vdritem.addr, WSUpdate, list_to_binary(WSUpdate)]),
		                                                                    send_msg_to_ws(WSUpdate, State),
		                                                                    %wsock_client:send(WSUpdate),
		                                                            
		                                                                    FlowIdx = NewState#vdritem.msgflownum,
		                                                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
		                                                                    common:loginfo("~p sends VDR (~p) response for 16#102 (ok) : ~p~n", [State#vdritem.pid, State#vdritem.addr, MsgBody]),
		                                                                    NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
		                                        
		                                                                    {ok, State#vdritem{id=VDRID, 
		                                                                                       serialno=binary_to_list(VDRSerialNo),
		                                                                                       auth=binary_to_list(VDRAuthenCode),
		                                                                                       vehicleid=VehicleID,
		                                                                                       vehiclecode=binary_to_list(VehicleCode),
		                                                                                       msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[],
																							   alarmlist=[]}};
		                                                                _ ->
		                                                                    {error, wserror, State}
		                                                            end;
																{ok, Reses} ->
																	AlarmList = get_alarm_list(Reses),
																	common:loginfo("Original AlarmList : ~p~n", [AlarmList]),		                                                            
		                                                            case wsock_data_parser:create_term_online([VehicleID]) of
		                                                                {ok, WSUpdate} ->
		                                                                    common:loginfo("VDR (~p) WS : ~p~n~p~n", [State#vdritem.addr, WSUpdate, list_to_binary(WSUpdate)]),
		                                                                    send_msg_to_ws(WSUpdate, State),
		                                                                    %wsock_client:send(WSUpdate),
		                                                            
		                                                                    FlowIdx = NewState#vdritem.msgflownum,
		                                                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
		                                                                    common:loginfo("~p sends VDR (~p) response for 16#102 (ok) : ~p~n", [State#vdritem.pid, State#vdritem.addr, MsgBody]),
		                                                                    NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
		                                        
		                                                                    {ok, State#vdritem{id=VDRID, 
		                                                                                       serialno=binary_to_list(VDRSerialNo),
		                                                                                       auth=binary_to_list(VDRAuthenCode),
		                                                                                       vehicleid=VehicleID,
		                                                                                       vehiclecode=binary_to_list(VehicleCode),
		                                                                                       msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[],
																							   alarmlist=AlarmList}};
		                                                                _ ->
		                                                                    {error, wserror, State}
		                                                            end
															end;
                                                        _ ->
                                                            % vdrtable error
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
                            common:loginfo("Invalid common message from unknown/unregistered/unauthenticated VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) MSG ID : ~p~n", [NewState#vdritem.addr, NewState#vdritem.id, NewState#vdritem.serialno, NewState#vdritem.auth, NewState#vdritem.vehicleid, NewState#vdritem.vehiclecode, ID]),
                            % Unauthorized/Unregistered VDR can only accept 16#100/16#102
                            {error, invaliderror, State}
                    end;
                true ->
					common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) MSG ID (~p), MSG Index (~p), MSG Tel (~p)~n",
								   [NewState#vdritem.addr, 
									NewState#vdritem.id, 
									NewState#vdritem.serialno, 
									NewState#vdritem.auth, 
									NewState#vdritem.vehicleid, 
									NewState#vdritem.vehiclecode, 
									ID, MsgIdx, Tel]),
                    case ID of
                        16#1 ->     % VDR general response
                            {RespFlowIdx, RespID, Res} = Msg,
                            
                            % Process reponse from VDR here
                            common:loginfo("Gateway (~p) receives VDR (~p) general response (16#1) : RespFlowIdx (~p), RespID (~p), Res (~p)~n", [State#vdritem.pid, State#vdritem.addr, RespFlowIdx, RespID, Res]),
                            
                            if
                                RespID == 16#8103 orelse 
									RespID == 16#8203 orelse	% has issue
									RespID == 16#8602 orelse	% need further tested
									RespID == 16#8603 orelse
									RespID == 16#8105 orelse
									RespID == 16#8202 orelse
									RespID == 16#8300 orelse
									RespID == 16#8302 orelse
									RespID == 16#8400 orelse
									RespID == 16#8401 orelse
									RespID == 16#8500 orelse
									RespID == 16#8801 orelse
									RespID == 16#8804
								  ->
                                    VehicleID = NewState#vdritem.vehicleid,

                                    [VDRItem] = ets:lookup(vdrtable, Socket),
                                    MsgList = VDRItem#vdritem.msgws2vdr,
                                    
                                    TargetList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID == RespID],
                                    case length(TargetList) of
                                        1 ->
                                            [{TargetWSID, TargetWSFlowIdx, _WSValue}] = TargetList,
                                            {ok, WSUpdate} = wsock_data_parser:create_gen_resp(TargetWSFlowIdx,
                                                                                               TargetWSID,
                                                                                               [VehicleID],
                                                                                               Res),
                                            common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, RespID, WSUpdate]),
                                            send_msg_to_ws(WSUpdate, NewState);
                                        ItemCount ->
                                            common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, RespID])
                                    end,
                                    
                                    NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= RespID],
                                    ets:insert(vdrtable, VDRItem#vdritem{msgws2vdr=NewMsgList}),
                                    
                                    {ok, NewState#vdritem{msgws2vdr=NewMsgList}};
                                true ->
                                    {ok, NewState}
                            end;
                        16#2 ->     % VDR pulse
                            % Nothing to do here
                            %{} = Msg,
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            common:loginfo("Gateway (~p) sends VDR (~p) response for 16#2 (Pulse) : ~p~n", [State#vdritem.pid, State#vdritem.addr, MsgBody]),
                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),

                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        16#3 ->     % VDR unregistration
                            %{} = Msg,
                            Auth = NewState#vdritem.auth,
                            ID = NewState#vdritem.id,
                            case create_sql_from_vdr(HeadInfo, {ID, Auth}, NewState) of
                                {ok, Sql} ->
                                    send_sql_to_db(conn, Sql, NewState),
        
                                    FlowIdx = NewState#vdritem.msgflownum,
                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                                    common:loginfo("~p sends VDR (~p) response for 16#3 (Position) : ~p~n", [State#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                    NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
        
                                    % return error to terminate connection with VDR
                                    {error, invaliderror, NewState#vdritem{msgflownum=NewFlowIdx}};
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
                                    PreviousAlarm = NewState#vdritem.alarm,
                                    
                                    {H, _AppInfo} = Msg,
                                    [AlarmSym, StateFlag, LatOri, LonOri, _Height, _Speed, _Direction, Time]= H,
                                    {Lat, Lon} = get_not_0_lat_lon(LatOri, LonOri, NewState),
                                    if
                                        AlarmSym == PreviousAlarm ->
		                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
		                                    common:loginfo("~p sends VDR (~p) response for 16#200 (ok) : ~p~n", [State#vdritem.pid, NewState#vdritem.addr, MsgBody]),
		                                    NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
		                                    
		                                    {ok, NewState#vdritem{msgflownum=NewFlowIdx, alarm=AlarmSym, lastlat=Lat, lastlon=Lon}};
                                        true ->
                                            <<Year:8, Month:8, Day:8, Hour:8, Minute:8, Second:8>> = <<Time:48>>,
                                            YearBin = common:integer_to_binary(common:convert_bcd_integer(Year)),
                                            MonthBin = common:integer_to_binary(common:convert_bcd_integer(Month)),
                                            DayBin = common:integer_to_binary(common:convert_bcd_integer(Day)),
                                            HourBin = common:integer_to_binary(common:convert_bcd_integer(Hour)),
                                            MinuteBin = common:integer_to_binary(common:convert_bcd_integer(Minute)),
                                            SecondBin = common:integer_to_binary(common:convert_bcd_integer(Second)),
                                            TimeS = binary_to_list(list_to_binary([YearBin, <<"-">>, MonthBin, <<"-">>, DayBin, <<" ">>, HourBin, <<":">>, MinuteBin, <<":">>, SecondBin])),
                                            TimeBinS = list_to_binary([<<"\"">>, YearBin, <<"-">>, MonthBin, <<"-">>, DayBin, <<" ">>, HourBin, <<":">>, MinuteBin, <<":">>, SecondBin, <<"\"">>]),
											
											AlarmList = update_vehicle_alarm(NewState#vdritem.vehicleid, NewState#vdritem.driverid, TimeS, AlarmSym, 0, NewState),
											if
												AlarmList == NewState#vdritem.alarmlist ->
													common:loginfo("No new alarms updated~n");
												AlarmList =/= NewState#vdritem.alarmlist ->
		                                            {ok, WSUpdate} = wsock_data_parser:create_term_alarm([NewState#vdritem.vehicleid],
		                                                                                                 FlowIdx,
		                                                                                                 common:combine_strings(["\"", NewState#vdritem.vehiclecode, "\""], false),
		                                                                                                 AlarmSym,
		                                                                                                 StateFlag,
		                                                                                                 Lat, 
		                                                                                                 Lon,
		                                                                                                 binary_to_list(TimeBinS)),
		                                            common:loginfo("Old alarms : ~p~nNew alarms : ~p~nVDR (~p) vehicle(~p) driver(~p) WS Alarm for 0x200: ~p~n", 
																   [NewState#vdritem.alarmlist, 
																	AlarmList,
																	NewState#vdritem.addr, 
																	NewState#vdritem.vehicleid, 
																	NewState#vdritem.driverid, 
																	WSUpdate]),
		                                            send_msg_to_ws(WSUpdate, NewState) %wsock_client:send(WSUpdate)
											end,

		                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
		                                    common:loginfo("~p sends VDR (~p) response for 16#200 (ok) : ~p~n", [State#vdritem.pid, NewState#vdritem.addr, MsgBody]),
		                                    NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
		                                    
		                                    {ok, NewState#vdritem{msgflownum=NewFlowIdx, alarm=AlarmSym, alarmlist=AlarmList, lastlat=Lat, lastlon=Lon}}
                                    end;%,
                                    
                                    %report_appinfo(AppInfo, NewState);
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
                            {_AnswerFlowIdx, AnswerID} = Msg,

                            VehicleID = NewState#vdritem.vehicleid,                            

                            [VDRItem] = ets:lookup(vdrtable, Socket),
                            MsgList = VDRItem#vdritem.msgws2vdr,

                            TargetList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID == 16#8302],
                            case length(TargetList) of
                                1 ->
                                    [{16#8302, TargetWSFlowIdx, _WSValue}] = TargetList,
                                    {ok, WSUpdate} = wsock_data_parser:create_term_answer(TargetWSFlowIdx,
																						  [VehicleID],
                                                                                          [AnswerID]),
                                    common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, 16#8302, WSUpdate]),
                                    send_msg_to_ws(WSUpdate, NewState);
                                ItemCount ->
                                    common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, 16#8302])
                            end,
                                    
                            NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= 16#8302],
                            ets:insert(vdrtable, VDRItem#vdritem{msgws2vdr=NewMsgList}),
                            
                            {ok, NewState#vdritem{msgws2vdr=NewMsgList}};
                        16#303 ->
                            {_MsgType, _POC} = Msg,
                            
                            {ok, NewState};
                        16#500 ->
                            {_FlowNum, Resp} = Msg,
                            {Info, _AppInfo} = Resp,
                            [_AlarmSym, InfoState, _Lat, _Lon, _Height, _Speed, _Direction, _Time] = Info,

                            VehicleID = NewState#vdritem.vehicleid,                            

                            [VDRItem] = ets:lookup(vdrtable, Socket),
                            MsgList = VDRItem#vdritem.msgws2vdr,

                            TargetList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID == 16#8500],
                            case length(TargetList) of
                                1 ->
                                    [{16#8500, TargetWSFlowIdx, WSValue}] = TargetList,
                                    FlagBit = WSValue band 1,
                                    ResBit = InfoState band 16#1000,
                                    NewResBit = ResBit bsr 12,
                                    % Not very clear about the latest parameter
                                    {ok, WSUpdate} = wsock_data_parser:create_vehicle_ctrl_answer(TargetWSFlowIdx,
                                                                                                  FlagBit bxor NewResBit,
                                                                                                  [VehicleID],
                                                                                                  [InfoState]),
                                    common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, 16#8500, WSUpdate]),
                                    send_msg_to_ws(WSUpdate, NewState);
                                ItemCount ->
                                    common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, 16#8500])
                            end,
                                    
                            NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= 16#8500],
                            ets:insert(vdrtable, VDRItem#vdritem{msgws2vdr=NewMsgList}),
                            
                            {ok, NewState#vdritem{msgws2vdr=NewMsgList}};
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
							{_MsgId, _MsgType, _MsgCode, _MsgEICode, _MsgPipeId} = Msg,
							
                            %{MsgId, MsgType, MsgCode, MsgEICode, MsgPipeId} = Msg,
                            %{Year, Month, Day} = date(),
                            %DBNAME = "VEHICLE_MULTIMEDIA_" ++ integer_to_list(Year) ++ integer_to_list(Month),
                            %TBLNAME = "'M_" ++ integer_to_list(Day) ++ "'",
                            %send_sql_to_db(conn, list_to_binary(["CREATE DATABASE IF NOT EXISTS ", DBNAME,
                            %                                     ";USE ",DBNAME,
                            %                                     ";CREATE TABLE IF NOT EXISTS ",TBLNAME,
                            %                                     "(`ID` INT(11) NOT NULL AUTO_INCREMENT,'MID' INT(1) NOT NULL,'TYPE' TINYINT(1) NOT NULL,'FormatCode' TINYINT(1) NOT NULL,'EventCode' TINYINT(1) NOT NULL,'PipeId' TINYINT(1) NOT NULL,PRIMARY KEY ('ID')) ENGINE=MyISAM DEFAULT CHARSET=utf8;insert into",TBLNAME,"(MID,TYPE,FormatCode,EventCode,PipeId) values(",ID,",",TYPE,",",CODE,",",EICODE,",",PIPEID,");"]), NewState),                            
                                                        
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            common:loginfo("~p sends VDR multimedia event information upload response (ok) : ~p~n", [NewState#vdritem.pid, MsgBody]),
                            NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),

							%{ok, NewState};
                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        16#801 ->
                            {_Id, _Type, _Code, _EICode, _PipeId, _MsgBody, Pack} = Msg,
							
							commmon:loginfo("@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@~nMultimedia data : ~p~n", [Pack]),
                            
                            {ok, NewState};
                        16#805 ->
                            {_RespIdx, Res, _ActLen, List} = Msg,

                            VehicleID = NewState#vdritem.vehicleid,                            

                            [VDRItem] = ets:lookup(vdrtable, Socket),
                            MsgList = VDRItem#vdritem.msgws2vdr,

                            TargetList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID == 16#8801],
                            case length(TargetList) of
                                1 ->
                                    [{16#8801, TargetWSFlowIdx, _WSValue}] = TargetList,
                                    {ok, WSUpdate} = wsock_data_parser:create_shot_resp(TargetWSFlowIdx,
                                                                                        [VehicleID],
																						Res,
																						List),
                                    common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, 16#8801, WSUpdate]),
                                    send_msg_to_ws(WSUpdate, NewState);
                                ItemCount ->
                                    common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, 16#8801])
                            end,
                                    
                            NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= 16#8801],
                            ets:insert(vdrtable, VDRItem#vdritem{msgws2vdr=NewMsgList}),
                            
                            {ok, NewState#vdritem{msgws2vdr=NewMsgList}};
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
                        16#100 ->
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(NewState#vdritem.auth)),
                            common:loginfo("~p sends VDR registration response (ok) : ~p~n", [NewState#vdritem.pid, MsgBody]),
                            NewFlowIdx = send_data_to_vdr(16#8100, FlowIdx, MsgBody, VDRPid),

                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        16#102 ->
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            common:loginfo("~p sends VDR (~p) response for 16#102 (ok) : ~p~n", [State#vdritem.pid, State#vdritem.addr, MsgBody]),
                            NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
                            
                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        _ ->
                            common:loginfo("Invalid message from registered/authenticated VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) MSG ID : ~p~n", [NewState#vdritem.addr, NewState#vdritem.id, NewState#vdritem.serialno, NewState#vdritem.auth, NewState#vdritem.vehicleid, NewState#vdritem.vehiclecode, ID]),
                            {error, invaliderror, NewState}
                    end
            end;
        {ignore, HeaderInfo, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
            common:loginfo("~p sends VDR (~p) response  ~p : ~p~n", [State#vdritem.pid, NewState#vdritem.addr, ID, MsgBody]),
            NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
            
            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
        {warning, HeaderInfo, ErrorType, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ErrorType),
            common:loginfo("~p sends VDR (~p) response for warning ~p : ~p~n", [State#vdritem.pid, NewState#vdritem.addr, ID, MsgBody]),
            NewFlowIdx = send_data_to_vdr(16#8001, FlowIdx, MsgBody, VDRPid),
            
            {warning, NewState#vdritem{msgflownum=NewFlowIdx}};
        {error, _ErrorType, NewState} ->    % exception/parityerror/formaterror
            {error, vdrerror, NewState}
    end.

get_alarm_list(AlarmList) when is_list(AlarmList),
							   length(AlarmList) > 0 ->
	[H|T] = AlarmList,
    {<<"vehicle_alarm">>, <<"type_id">>, TypeId} = get_record_field(<<"vehicle_alarm">>, H, <<"type_id">>),
    {<<"vehicle_alarm">>, <<"alarm_time">>, {datetime, {{YY,MM,DD},{Hh,Mm,Ss}}}} = get_record_field(<<"vehicle_alarm">>, H, <<"alarm_time">>),
	YYS = integer_to_list(vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(YY))),
	MMS = integer_to_list(MM),
	DDS = integer_to_list(DD),
	HhS = integer_to_list(Hh),
	MmS = integer_to_list(Mm),
	SsS = integer_to_list(Ss),
	DTS = common:combine_strings([YYS, "-", MMS, "-", DDS, " ", HhS, ":", MmS, ":", SsS], false),
	common:loginfo("vehicle_alarm : type_id (~p), alarm_time (~p)~n", [TypeId, DTS]),
	Cur = [{TypeId, DTS}],
	case T of
		[] ->
			Cur;
		_ ->
			Res = get_alarm_list(T),
			case get_alarm_item(TypeId, Res) of
				empty ->
					lists:merge(Cur, Res);
				_ ->
					Res	
		end			
	end;
get_alarm_list(_AlarmList) ->
	[].

update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, State) ->
    {Year, Month, Day} = erlang:date(),
    {Hour, Minute, Second} = erlang:time(),
    DateTime = integer_to_list(Year) ++ "-" ++ 
                   integer_to_list(Month) ++ "-" ++ 
                   integer_to_list(Day) ++ " " ++ 
                   integer_to_list(Hour) ++ ":" ++ 
                   integer_to_list(Minute) ++ ":" ++ 
                   integer_to_list(Second),
    if
        DeviceRegTime == undefined ->
            DevInstallTimeSql = list_to_binary([<<"update vehicle set dev_install_time='">>,
                                                list_to_binary(DateTime),
                                                <<"' where id=">>,
                                                common:integer_to_binary(VehicleID)]),
            % Should we check the update result?
            %end_sql_to_db(regauth, DevInstallTimeSql, State);
            send_sql_to_db(conn, DevInstallTimeSql, State);
        true ->
            ok
    end,
    if
        VehicleDeviceInstallTime == undefined ->
            VDRRegTimeSql = list_to_binary([<<"update device set reg_time='">>,
                                            list_to_binary(DateTime),
                                            <<"' where id=">>,
                                            common:integer_to_binary(DeviceID)]),
            % Should we check the update result?
            %send_sql_to_db(regauth, VDRRegTimeSql, State);
            send_sql_to_db(conn, VDRRegTimeSql, State);
        true ->
            ok
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Parameters :
%       VehicleID   : Integer
%       DriverID    : Integer
%       TimeS       : String
%       Alarm       : Integer
%       Index       : Integer 0 - 31
%       AlarmList   : List
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index, State) when is_integer(VehicleID),
                                                                           is_integer(DriverID),
                                                                           is_integer(Index),
                                                                           is_list(TimeS),
                                                                           is_integer(Alarm),
                                                                           Index >= 0,
                                                                           Index =< 31 ->
	AlarmList = State#vdritem.alarmlist,
    Flag = 1 bsl Index,
	BitState = Alarm band Flag,
    %common:loginfo("Alarm List: ~p~n", [AlarmList]),
    %common:loginfo("Alarm(~p) & Flag(~p) = BitState(~p)~n", [Alarm, Flag, BitState]),
	if
		BitState == 1 ->
            %common:loginfo("Vehicle(~p) driver(~p) check alarm(~p:~p) for set~n", [VehicleID, DriverID, Alarm, Index]),
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    common:loginfo("Vehicle(~p) driver(~p) inserts new alarm(~p:~p) when ~p with alarm list~p~n", [VehicleID, DriverID, Alarm, Index, TimeS, AlarmList]),
                    UpdateSql = list_to_binary([<<"insert into vehicle_alarm(vehicle_id,driver_id,alarm_time,clear_time,type_id) values(">>,
                                                common:integer_to_binary(VehicleID), <<",">>,
                                                common:integer_to_binary(DriverID), <<",'">>,
                                                list_to_binary(TimeS), <<"',NULL,">>,
                                                common:integer_to_binary(Index), <<")">>]),
                    common:loginfo("Alarm SQL : ~p~n", [UpdateSql]),
                    send_sql_to_db(conn, UpdateSql, State),
					common:loginfo("AlarmList : ~p\n[{Index, TimeS}] : ~p, ~p\n", [AlarmList, Index, TimeS]),
                    NewAlarmList = lists:merge(AlarmList,[{Index, TimeS}]),
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State#vdritem{alarmlist=NewAlarmList});
                true ->
                    %{Index, SetTime} = AlarmEntry,
                    %common:loginfo("Vehicle(~p) driver(~p) keeps alarm(~p:~p) when ~p~n", [VehicleID, DriverID, Alarm, Index, SetTime]),
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State)
            end;
		true ->
            %common:loginfo("Vehicle(~p) driver(~p) check alarm(~p:~p) for clear~n", [VehicleID, DriverID, Alarm, Index]),
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State);
                true ->
                    {Index, SetTime} = AlarmEntry,
                    common:loginfo("Vehicle(~p) driver(~p) clears alarm(~p:~p) for ~p with alarm list~p~n", [VehicleID, DriverID, Alarm, Index, SetTime, AlarmList]),
                    UpdateSql = list_to_binary([<<"update vehicle_alarm set clear_time='">>, list_to_binary(TimeS),
                                                <<"' where vehicle_id=">>, common:integer_to_binary(VehicleID),
                                                <<" and driver_id=">>, common:integer_to_binary(DriverID),
                                                <<" and alarm_time='">>, list_to_binary(SetTime),
                                                <<"' and type_id=">>, common:integer_to_binary(Index)]),
                    common:loginfo("Alarm SQL : ~p~n", [UpdateSql]),
                    send_sql_to_db(conn, UpdateSql, State),
					common:loginfo("AlarmList : ~p\n[{Index, TimeS}] : ~p, ~p\n", [AlarmList, Index, TimeS]),
                    NewAlarmList = remove_alarm_item(Index, AlarmList),
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State#vdritem{alarmlist=NewAlarmList})
            end
	end;
update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index, State) when is_integer(VehicleID),
                                                                           %is_integer(DriverID),
                                                                           is_integer(Index),
                                                                           is_list(TimeS),
                                                                           is_integer(Alarm),
                                                                           Index >= 0,
                                                                           Index =< 31 ->
    AlarmList = State#vdritem.alarmlist,
    Flag = 1 bsl Index,
    BitState = Alarm band Flag,
    %common:loginfo("Alarm List: ~p~n", [AlarmList]),
    %common:loginfo("Alarm(~p) & Flag(~p) = BitState(~p)~n", [Alarm, Flag, BitState]),
    if
        BitState == Flag ->
            %common:loginfo("Vehicle(~p) driver(~p) check alarm(~p:~p) for set~n", [VehicleID, _DriverID, Alarm, Index]),
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    common:loginfo("Vehicle(~p) driver(~p) inserts new alarm(~p:~p) when ~p with alarm list ~p~n", [VehicleID, _DriverID, Alarm, Index, TimeS, AlarmList]),
                    UpdateSql = list_to_binary([<<"insert into vehicle_alarm(vehicle_id,driver_id,alarm_time,clear_time,type_id) values(">>,
                                                common:integer_to_binary(VehicleID), <<",0,'">>,
                                                list_to_binary(TimeS), <<"',NULL,">>,
                                                common:integer_to_binary(Index), <<")">>]),
                    common:loginfo("Alarm SQL : ~p~n", [UpdateSql]),
                    send_sql_to_db(conn, UpdateSql, State),
					common:loginfo("AlarmList : ~p\n[{Index, TimeS}] : ~p, ~p\n", [AlarmList, Index, TimeS]),
                    NewAlarmList = lists:merge(AlarmList,[{Index, TimeS}]),
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State#vdritem{alarmlist=NewAlarmList});
                true ->
                    %{Index, SetTime} = AlarmEntry,
                    %common:loginfo("Vehicle(~p) driver(~p) keeps alarm(~p:~p) when ~p~n", [VehicleID, _DriverID, Alarm, Index, SetTime]),
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State)
            end;
        true ->
            %common:loginfo("Vehicle(~p) driver(~p) check alarm(~p:~p) for clear~n", [VehicleID, _DriverID, Alarm, Index]),
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State);
                true ->
                    {Index, SetTime} = AlarmEntry,
                    common:loginfo("Vehicle(~p) driver(~p) clears alarm(~p:~p) for ~p with alarm list~p~n", [VehicleID, _DriverID, Alarm, Index, SetTime, AlarmList]),
                    UpdateSql = list_to_binary([<<"update vehicle_alarm set clear_time='">>, list_to_binary(TimeS),
                                                <<"' where vehicle_id=">>, common:integer_to_binary(VehicleID),
                                                <<" and driver_id=0 and alarm_time='">>, list_to_binary(SetTime),
                                                <<"' and type_id=">>, common:integer_to_binary(Index)]),
                    common:loginfo("Alarm SQL : ~p~n", [UpdateSql]),
                    send_sql_to_db(conn, UpdateSql, State),
					common:loginfo("AlarmList : ~p\n[{Index, TimeS}] : ~p, ~p\n", [AlarmList, Index, TimeS]),
                    NewAlarmList = remove_alarm_item(Index, AlarmList),
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State#vdritem{alarmlist=NewAlarmList})
            end
    end;
update_vehicle_alarm(_VehicleID, _DriverID, _TimeS, _Alarm, _Index, State) ->
	State#vdritem.alarmlist.

get_alarm_item(Index, AlarmList) when is_integer(Index),
                                      is_list(AlarmList),
                                      length(AlarmList) > 0,
                                      Index >= 0,
                                      Index =< 31 ->
    [H|T] = AlarmList,
    {Idx, _Time} = H,
    if
        Index == Idx ->
            H;
        true ->
            get_alarm_item(Index, T)
    end;
get_alarm_item(_Index, _AlarmList) ->
    empty.

remove_alarm_item(Index, AlarmList) when is_integer(Index),
                                         is_list(AlarmList),
                                         length(AlarmList) > 0,
                                         Index >= 0,
                                         Index =< 31 ->
    [H|T] = AlarmList,
    {Idx, _Time} = H,
    if
        Index == Idx ->
            case T of
                [] ->
                    [];
                _ ->
                    remove_alarm_item(Index, T)
            end;
        true ->
            case T of
                [] ->
                    [H];
                _ ->
                    lists:merge([H], remove_alarm_item(Index, T))
            end
    end;
remove_alarm_item(_Index, AlarmList) ->
    AlarmList.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Diconnect socket and remove related entries from vdrtable
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
disconn_socket_by_id(SockList) when is_list(SockList),
                                    length(SockList) > 0 ->
    case SockList of
        [] ->
            ok;
        _ ->
            [H|T] = SockList,
            [Sock] = H,
            try gen_tcp:close(Sock)
            catch
                _ ->
                    ok
            end,
            ets:delete(vdrtable, Sock),
            disconn_socket_by_id(T)
    end;
disconn_socket_by_id(_SockList) ->
    ok.

disconn_socket_by_id(SockList, SelfSock) when is_list(SockList),
                                              length(SockList) > 0 ->
    [H|T] = SockList,
    [Sock] = H,
	if
		SelfSock =/= Sock ->
			%common:loginfo("Disconnect socket ~p because of being not ~p~n", [Sock, SelfSock]),
            try
				gen_tcp:close(Sock)
			catch
				_:_ ->
					ok
			end,
            ets:delete(vdrtable, Sock);
		true ->
			%common:loginfo("NOT disconnect socket ~p because of being ~p~n", [Sock, SelfSock]),
			ok
	end,
    disconn_socket_by_id(T, SelfSock);
disconn_socket_by_id(_SockList, _SelfSock) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ID        :
% FlowIdx   :
% MsgBody   :
% Pid       :
% VDRPid    :
%
% Return	: the next message index
%		10,20,30,40,... is for the index of the message from WS to VDR
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_data_to_vdr(ID, FlowIdx, MsgBody, VDRPid) ->
    case VDRPid of
        undefined ->
            FlowIdx;
        _ ->
            Pid = self(),
            %common:loginfo("~p send_data_to_vdr : ID (~p), FlowIdx (~p), MsgBody (~p)~n", [Pid, ID, FlowIdx, MsgBody]),
            Msg = vdr_data_processor:create_final_msg(ID, FlowIdx, MsgBody),
			if
				Msg == <<>> ->
					common:loginfo("~p send_data_to_vdr NULL final message : ID (~p), FlowIdx (~p), MsgBody (~p)~n", [Pid, ID, FlowIdx, MsgBody]);
				Msg =/= <<>> ->
					%common:loginfo("~p send_data_to_vdr final message : ID (~p), FlowIdx (~p), Msg (~p)~n", [Pid, ID, FlowIdx, Msg]),
					VDRPid ! {Pid, Msg},
					%receive
					%    {Pid, vdrok} ->
					%        FlowIdx + 1
					%end
					NewFlowIdx = FlowIdx + 1,
					NewFlowIdxRem = NewFlowIdx rem ?WS2VDRFREQ,
					case NewFlowIdxRem of
						0 ->
							NewFlowIdx + 1;
						_ ->
							FlowIdxRem = FlowIdx rem ?WS2VDRFREQ,
							case FlowIdxRem of
								0 ->
									FlowIdx + ?WS2VDRFREQ;
								_ ->
									NewFlowIdx
							end
					end
			end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
data2vdr_process(Socket) ->
    %common:loginfo("~p is waiting for MSG to VDR~n", [self()]),
    receive
		{Pid, stop} ->
			common:loginfo("~p stops waiting for MSG to VDR by ~p~n", [self(), Pid]),
			Pid ! {Pid, stopped};
        {Pid, Msg} ->
            common:loginfo("~p receives MSG to VDR from ~p : ~p~n", [self(), Pid, Msg]),
            gen_tcp:send(Socket, Msg),
            %Pid ! {Pid, vdrok},
            data2vdr_process(Socket);
        %stop ->
        %    common:loginfo("~p stops waiting for MSG to VDR~n", [self()]),
        %    ok;
        _ ->
            data2vdr_process(Socket)
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
resp2ws_process(List) ->
    receive
        _ ->
            resp2ws_process(List)
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_sql_to_db(PoolId, Msg, State) ->
    case State#vdritem.dbpid of
        undefined ->
            common:loginfo("Cannot send SQL (~p) to DB process (undefined) : ~p~n", [Msg, PoolId]),
            ok;
        DBPid ->
            common:loginfo("Send SQL (~p) to DB process (~p) : ~p~n", [Msg, DBPid, PoolId]),
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_msg_to_ws(Msg, State) ->
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
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
vdr_msg_monitor_process(Pid, Socket) ->
	receive
		{Pid, stop} ->
			[State] = ets:lookup(vdrtable, Socket),
			common:loginfo("VDR (~p) socket (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) : message monitor process received stop command and stops",
						   [State#vdritem.addr,
							State#vdritem.socket,
							State#vdritem.id, 
							State#vdritem.serialno, 
							State#vdritem.auth, 
							State#vdritem.vehicleid, 
							State#vdritem.vehiclecode]),
			Pid ! {Pid, stopped};
		{Pid, Socket} ->
			Pid ! {Pid, ok},
			vdr_msg_monitor_process(Pid, Socket);
		_ ->
			[State] = ets:lookup(vdrtable, Socket),
			terminate("VDR message monitor process received unknown command and stops", State)
	after ?VDR_MSG_TIMEOUT ->
			[State] = ets:lookup(vdrtable, Socket),
			terminate("VDR message monitor process timeout and stops", State)
	end.			

%%%         
%%% Return :
%%%     {ok, SQL|[SQL0, SQL1, ...]}
%%%     {error, iderror}
%%%     error
%%%
create_sql_from_vdr(HeaderInfo, Msg, State) ->
    {ID, _FlowNum, TelNum, _CryptoType} = HeaderInfo,
    case ID of
        16#1    ->
            {ok, ""};
        16#2    ->                          
            {ok, ""};
        16#100  ->          % Not complete, currently only use VDRSerialNo&VehicleID for query                     
            {_Province, _City, _Producer, _VDRModel, _VDRSerialNo, _VehicleColor, _VehicleID} = Msg,
			<<Num0:8, Num1:8, Num2:8, Num3:8, Num4:8, Num5:8>> = <<TelNum:48>>,
			TelBin = list_to_binary([common:integer_to_binary(common:convert_bcd_integer(Num0)),
				    				 common:integer_to_2byte_binary(common:convert_bcd_integer(Num1)),
									 common:integer_to_2byte_binary(common:convert_bcd_integer(Num2)),
									 common:integer_to_2byte_binary(common:convert_bcd_integer(Num3)),
									 common:integer_to_2byte_binary(common:convert_bcd_integer(Num4)),
									 common:integer_to_2byte_binary(common:convert_bcd_integer(Num5))]),
            SQL = list_to_binary([<<"select * from vehicle,device where device.iccid='">>,%serial_no='">>,
                                  %list_to_binary(VDRSerialNo),
								  TelBin,
                                  %<<"' and vehicle.code='">>,
                                  %list_to_binary(VehicleID),
                                  %<<"'">>]),
								  <<"' and vehicle.device_id=device.id">>]),
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
                    [AlarmSym, StateFlag, LatOri, LonOri, Height, Speed, Direction, Time]= H,
                    {Lat, Lon} = get_not_0_lat_lon(LatOri, LonOri, State),
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
                    YearDB = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Year)),
                    MonthDB = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Month)),
                    DayDB = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Day)),
                    DBBin = list_to_binary([common:integer_to_2byte_binary(YearDB),
                                             common:integer_to_2byte_binary(MonthDB),
                                             common:integer_to_2byte_binary(DayDB)]),
                    ServerYearS = common:integer_to_binary(ServerYear),
                    ServerMonthS = common:integer_to_binary(ServerMonth),
                    ServerDayS = common:integer_to_binary(ServerDay),
                    ServerHourS = common:integer_to_binary(ServerHour),
                    ServerMinuteS = common:integer_to_binary(ServerMinute),
                    ServerSecondS = common:integer_to_binary(ServerSecond),
                    ServerTimeS = list_to_binary([ServerYearS, <<"-">>, ServerMonthS, <<"-">>, ServerDayS, <<" ">>, ServerHourS, <<":">>, ServerMinuteS, <<":">>, ServerSecondS]),
                    VehicleID = State#vdritem.vehicleid,
                    SQL0 = list_to_binary([<<"insert into vehicle_position_">>, DBBin,
                                           <<"(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:float_to_binary(Lon/1000000.0), <<", ">>,
                                          common:float_to_binary(Lat/1000000.0), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:float_to_binary(Speed/10.0), <<", ">>,
                                          common:integer_to_binary(Direction), <<", ">>,
                                          common:integer_to_binary(StateFlag), <<", ">>,
                                          common:integer_to_binary(AlarmSym), <<")">>]),
                    SQL1 = list_to_binary([<<"replace into vehicle_position_last(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:float_to_binary(Lon/1000000.0), <<", ">>,
                                          common:float_to_binary(Lat/1000000.0), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:float_to_binary(Speed/10.0), <<", ">>,
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
                    YearDB = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Year)),
                    MonthDB = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Month)),
                    DayDB = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Day)),
                    DBBin = list_to_binary([common:integer_to_2byte_binary(YearDB),
                                             common:integer_to_2byte_binary(MonthDB),
                                             common:integer_to_2byte_binary(DayDB)]),
                    ServerYearS = common:integer_to_binary(ServerYear),
                    ServerMonthS = common:integer_to_binary(ServerMonth),
                    ServerDayS = common:integer_to_binary(ServerDay),
                    ServerHourS = common:integer_to_binary(ServerHour),
                    ServerMinuteS = common:integer_to_binary(ServerMinute),
                    ServerSecondS = common:integer_to_binary(ServerSecond),
                    ServerTimeS = list_to_binary([ServerYearS, <<"-">>, ServerMonthS, <<"-">>, ServerDayS, <<" ">>, ServerHourS, <<":">>, ServerMinuteS, <<":">>, ServerSecondS]),
                    VehicleID = State#vdritem.vehicleid,
                    SQL0 = list_to_binary([<<"insert into vehicle_position_">>, DBBin,
                                           <<"(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:float_to_binary(Lon/1000000.0), <<", ">>,
                                          common:float_to_binary(Lat/1000000.0), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:float_to_binary(Speed/10.0), <<", ">>,
                                          common:integer_to_binary(Direction), <<", ">>,
                                          common:integer_to_binary(StateFlag), <<", ">>,
                                          common:integer_to_binary(AlarmSym), <<")">>]),
                    SQL1 = list_to_binary([<<"replace into vehicle_position_last(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag) values(">>,
                                          common:integer_to_binary(VehicleID), <<", '">>,
                                          TimeS, <<"', '">>,
                                          ServerTimeS, <<"', ">>,
                                          common:float_to_binary(Lon/1000000.0), <<", ">>,
                                          common:float_to_binary(Lat/1000000.0), <<", ">>,
                                          common:integer_to_binary(Height), <<", ">>,
                                          common:float_to_binary(Speed/10.0), <<", ">>,
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

get_not_0_lat_lon(Lat, Lon, State) ->
    case Lat of
        0.0 ->
            case Lon of
                0.0 ->
                    {State#vdritem.lastlat, State#vdritem.lastlon};
                _ ->
                    {State#vdritem.lastlat, Lon}
            end;
        _ ->
            case Lon of
                0.0 ->
                    {Lat, State#vdritem.lastlon};
                _ ->
                    {Lat, Lon}
            end
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


