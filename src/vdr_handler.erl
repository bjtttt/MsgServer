-module(vdr_handler).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-export([process_vdr_data/3,
         send_data_to_vdr/5,
		 extract_db_resp/1,
		 get_record_field/3,
		 send_sql_to_db/3,
		 send_sql_to_db_nowait/3,
		 send_msg_to_ws/2]).

-include("header.hrl").
-include("mysql.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Sock, Addr]) ->
    process_flag(trap_exit, true),
    Pid = self(),
    %VDRPid = spawn(fun() -> data2vdr_process(Sock) end),
    [{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
    [{wspid, WSPid}] = ets:lookup(msgservertable, wspid),
    [{ccpid, CCPid}] = ets:lookup(msgservertable, ccpid),
    [{linkpid, LinkPid}] = ets:lookup(msgservertable, linkpid),
    [{vdrtablepid, VDRTablePid}] = ets:lookup(msgservertable, vdrtablepid),
    [{vdrresppid, VDRRespPid}] = ets:lookup(msgservertable, vdrresppid),
<<<<<<< HEAD
    State = #vdritem{socket=Sock, pid=Pid, vdrpid=VDRRespPid, addr=Addr, msgflownum=1, errorcount=0, dbpid=DBPid, wspid=WSPid, ccpid=CCPid, linkpid=LinkPid, vdrtablepid=VDRTablePid},
=======
	%VDRMonitorPid = spawn(fun() -> vdr_monitor_process(Pid, Sock) end),
    State = #vdritem{socket=Sock, pid=Pid, vdrpid=VDRRespPid, addr=Addr, msgflownum=1, errorcount=0, 
					 dbpid=DBPid, wspid=WSPid, ccpid=CCPid, linkpid=LinkPid, vdrtablepid=VDRTablePid},
					 %vdrmonitorpid=VDRMonitorPid},
>>>>>>> e72ca3b7277448aa6b7ac9e80ff409e581833ecf
	common:send_stat_err(State, conn),
    common:send_vdr_table_operation(VDRTablePid, {self(), insert, State, noresp}),
    inet:setopts(Sock, [{active, once}]),
	{ok, State, ?VDR_MSG_TIMEOUT}.

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
	LinkPid = OriState#vdritem.linkpid,
	Pid = OriState#vdritem.pid,
<<<<<<< HEAD
	LinkPid ! {Pid, vdrmsggot},
=======
	%VDRMonitorPid = OriState#vdritem.vdrmonitorpid,
	LinkPid ! {Pid, vdrmsggot},
	%VDRMonitorPid ! {Pid, pulse},
>>>>>>> e72ca3b7277448aa6b7ac9e80ff409e581833ecf
    %common:loginfo("~p : Data from VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~n~p~n",
	%			   [self(),
	%				OriState#vdritem.addr, 
	%				OriState#vdritem.id, 
	%				OriState#vdritem.serialno, 
	%				OriState#vdritem.auth, 
	%				OriState#vdritem.vehicleid, 
	%				OriState#vdritem.vehiclecode,
	%				Data]),
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
	%DataDebug = <<126,8,1,34,36,1,52,1,8,18,33,54,69,0,34,0,1,81,234,120,125,1,1,3,0,0,0,8,0,0,0,0,0,19,2,97,189,24,6,238,86,48,0,95,0,86,0,0,19,7,32,17,70,3,82,73,70,70,160,66,0,0,87,65,86,69,102,109,116,32,16,0,0,0,1,0,1,0,64,31,0,0,128,62,0,0,2,0,16,0,100,97,116,97,124,66,0,0,199,255,216,255,218,255,200,255,194,255,178,255,169,255,169,255,155,255,145,255,213,255,227,255,198,255,237,255,244,255,242,255,21,0,52,0,68,0,68,0,68,0,54,0,54,0,44,0,66,0,45,0,65,0,59,0,50,0,12,0,246,255,246,255,216,255,215,255,202,255,172,255,144,255,132,255,157,255,175,255,154,255,147,255,152,255,186,255,172,255,151,255,162,255,172,255,153,255,136,255,138,255,180,255,150,255,128,255,91,255,97,255,82,255,50,255,87,255,81,255,109,255,144,255,162,255,156,255,141,255,152,255,165,255,209,255,227,255,213,255,202,255,210,255,189,255,178,255,160,255,188,255,186,255,242,255,250,255,33,0,28,0,32,0,15,0,46,0,52,0,82,0,66,0,55,0,44,0,33,0,249,255,225,255,188,255,217,255,228,255,243,255,2,0,16,0,225,255,203,255,212,255,198,255,184,255,168,255,182,255,143,255,125,1,255,186,255,212,255,206,255,251,255,255,255,18,0,17,0,28,0,12,0,19,0,49,0,58,0,35,0,50,0,87,0,104,0,64,0,23,0,224,255,221,255,239,255,11,0,24,0,42,0,41,0,24,0,18,0,6,0,29,0,48,0,19,0,250,255,10,0,20,0,238,255,239,255,179,255,167,255,168,255,171,255,164,255,202,255,200,255,181,255,220,255,228,255,225,255,228,255,170,255,171,255,206,255,222,255,229,255,235,255,245,255,235,255,4,0,247,255,231,255,228,255,2,0,231,255,244,255,232,255,245,255,4,0,37,0,33,0,81,0,55,0,69,0,47,0,53,0,67,0,56,0,42,0,46,0,58,0,35,0,255,255,230,255,196,255,186,255,209,255,193,255,194,255,227,255,231,255,230,255,214,255,189,255,154,255,147,255,153,255,157,255,168,255,168,255,191,255,181,255,204,255,252,255,240,255,1,0,235,255,243,255,238,255,241,255,251,255,229,255,215,255,231,255,224,255,248,255,236,255,248,255,45,0,25,0,12,0,21,0,5,0,243,255,226,255,185,255,151,255,162,255,173,255,225,255,231,126>>,
	%DataDebug = <<126,8,5,0,9,1,52,1,8,18,33,5,59,0,0,0,0,1,0,0,0,2,54,126>>,
	%DataDebug = <<126,8,5,0,9,1,52,1,8,18,33,2,125,2,0,10,0,0,1,0,0,0,2,125,2,126>>,
	%DataDebug = <<126,7,2,0,7,1,52,1,8,18,33,0,13,2,19,8,48,22,41,22,0,126>>,
	%DataDebug = <<126,7,2,0,50,1,52,1,8,18,33,1,18,1,19,9,3,18,54,9,0,8,53,54,185,220,192,237,212,177,49,50,51,52,53,54,55,56,56,56,57,48,49,50,51,52,57,57,0,0,8,183,162,214,164,187,250,185,185,0,24,7,5,9,126>>,
	%DataDebug = <<126,7,2,0,50,1,52,1,8,18,33,0,11,1,19,9,3,21,8,87,0,8,53,54,185,220,192,237,212,177,49,50,51,52,53,54,55,56,56,56,57,48,49,50,51,52,57,57,0,0,8,183,162,214,164,187,250,185,185,0,24,7,5,118,126>>,
	%DataDebug = <<126,2,0,0,64,1,50,97,51,36,129,0,120,0,0,0,0,0,12,0,19,2,97,0,56,6,241,103,104,0,48,0,100,0,1,19,16,24,21,73,2,1,4,0,0,0,160,2,2,0,0,3,2,0,0,37,4,0,0,0,0,42,2,0,0,43,4,0,0,0,0,48,1,0,49,1,17,192,126>>,
    Msgs = common:split_msg_to_single(Data, 16#7e),
    %Msgs = common:split_msg_to_single(DataDebug, 16#7e),
    case Msgs of
        [] ->
			common:send_stat_err(State, spliterr),
            ErrCount = State#vdritem.errorcount + 1,
            common:logerror("VDR (~p) data empty : continous error count is ~p (max is 3)~n", [State#vdritem.addr, ErrCount]),
            if
                ErrCount >= ?MAX_VDR_ERR_COUNT ->
					common:send_stat_err(State, errdisc),
					common:send_stat_err(State, gwstop),
                    {stop, vdrerror, State#vdritem{errorcount=ErrCount}};
                true ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, State#vdritem{errorcount=ErrCount}, ?VDR_MSG_TIMEOUT}
            end;    
        _ ->
            case process_vdr_msges(Socket, Msgs, State) of
                {error, vdrerror, NewState} ->
                    ErrCount = NewState#vdritem.errorcount + 1,
                    common:logerror("VDR (~p) data error : continous count is ~p (max is 3)~n", [NewState#vdritem.addr, ErrCount]),
                    if
                        ErrCount >= ?MAX_VDR_ERR_COUNT ->
							common:send_stat_err(State, errdisc),
							common:send_stat_err(State, gwstop),
                            {stop, vdrerror, NewState#vdritem{errorcount=ErrCount}};
                        true ->
                            inet:setopts(Socket, [{active, once}]),
                            {noreply, NewState#vdritem{errorcount=ErrCount}, ?VDR_MSG_TIMEOUT}
                    end;
                {error, ErrType, NewState} ->
					if
						ErrType == charerror ->
							common:send_stat_err(State, chardisc);
						ErrType == regerror ->
							common:send_stat_err(State, regdisc);
						ErrType == autherror ->
							common:send_stat_err(State, authdisc);
						ErrType == unautherror ->
							common:send_stat_err(State, unauthdisc);
						ErrType == invalidmsgerror ->
							common:send_stat_err(State, invalidmsgerror);
						ErrType == exiterror ->
							common:send_stat_err(State, exitdisc);
						ErrType == vdrerror ->
							common:send_stat_err(State, vdrerror);
						ErrType == unvdrerror ->
							common:send_stat_err(State, unvdrerror);
						ErrType == exception ->
							common:send_stat_err(State, msgex);
						true ->
							common:send_stat_err(State, errdisc)
					end,
					common:send_stat_err(State, gwstop),
                    {stop, ErrType, NewState};
                {warning, NewState} ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, NewState#vdritem{errorcount=0}, ?VDR_MSG_TIMEOUT};
                {ok, NewState} ->
                    inet:setopts(Socket, [{active, once}]),
                    {noreply, NewState#vdritem{errorcount=0}, ?VDR_MSG_TIMEOUT}
            end
    end;
handle_info({tcp_closed, _Socket}, State) ->    
	common:send_stat_err(State, clientdisc),
	{stop, tcp_closed, State};
handle_info(timeout, State) ->
	common:send_stat_err(State, vdrtimeout),
	{stop, vdrtimeout, State};
handle_info(_Info, State) ->    
	{stop, unknown, State}. 

%%%
%%% When VDR handler process is terminated, do the clean jobs here
%%%
terminate(_Reason, State) ->
    VehicleID = State#vdritem.vehicleid,
    Socket = State#vdritem.socket,
    VDRTablePid = State#vdritem.vdrtablepid,
	Pid = State#vdritem.pid,
<<<<<<< HEAD
    %case VDRPid of
    %    undefined ->
    %        ok;
    %    _ ->
    %        VDRPid ! {Pid, stop, noresp}
    %end,
=======
	%VDRMonitorPid = State#vdritem.vdrmonitorpid,
>>>>>>> e72ca3b7277448aa6b7ac9e80ff409e581833ecf
    case Socket of
        undefined ->
            ok;
        _ ->
            common:send_vdr_table_operation(VDRTablePid, {Pid, delete, Socket, noresp})
    end,
    case VehicleID of
        undefined ->
            ok;
        _ ->
            {ok, WSUpdate} = wsock_data_parser:create_term_offline([VehicleID]),
            send_msg_to_ws_nowait(WSUpdate, State)
    end,
<<<<<<< HEAD
    %case Auth of
    %    undefined ->
    %        ok;
    %    _ ->
			%Sql = list_to_binary([<<"replace into device(authen_code,is_online) values('">>, Auth, <<"',0)">>]),
			%%Sql = list_to_binary([<<"update device set is_online=0 where authen_code='">>, 
            %%                      list_to_binary(Auth), 
            %%                      <<"'">>]),
            %send_sql_to_db_nowait(conn, Sql, State)
    %end,
=======
	%case VDRMonitorPid of
	%	undefined ->
	%		ok;
	%	_ ->
	%		VDRMonitorPid ! stop
	%end,
>>>>>>> e72ca3b7277448aa6b7ac9e80ff409e581833ecf
	try gen_tcp:close(State#vdritem.socket)
    catch
        _:Ex ->
            common:logerror("VDR (~p) : exception when gen_tcp:close : ~p~n", [State#vdritem.addr, Ex])
    end.
    %common:loginfo("~p VDR (~p) socket (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) is terminated : ~p",
	%			   [self(),
	%				State#vdritem.addr,
	%				State#vdritem.socket,
	%				State#vdritem.id, 
	%				State#vdritem.serialno, 
	%				State#vdritem.auth, 
	%				State#vdritem.vehicleid, 
	%				State#vdritem.vehiclecode,
	%				Reason]).

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}.

%%%
%%% Return :
%%%     {ok, State}
%%%     {warning, State}
%%%     {error, vdrerror/invaliderror/systemerror/exception/unknown, State}  
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
%%%     {error, systemerror/vdrerror/invaliderror/exception, State}  
%%%
safe_process_vdr_msg(Socket, Msg, State) ->
    try process_vdr_data(Socket, Msg, State)
    catch
        _ ->
			[ST] = erlang:get_stacktrace(),
			common:logerror("Exception MSG : ~p~nStack trace :~n~p", [Msg, ST]),
            {error, exception, State}
    end.

%%%
%%% This function should refer to the document on the mechanism
%%%
%%% Return :
%%%     {ok, State}
%%%     {warning, State}
%%%     {error, systemerror/vdrerror/invaliderror/exception, State}  
%%%
%%% MsgIdx  : VDR message index
%%% FlowIdx : Gateway message flow index
%%%
process_vdr_data(Socket, Data, State) -> 
	VDRPid = State#vdritem.vdrpid,
    case vdr_data_parser:process_data(State, Data) of
        {ok, HeadInfo, Msg, NewState} ->
            {ID, MsgIdx, Tel, _CryptoType} = HeadInfo,
            if
                State#vdritem.id == undefined ->
            		%common:loginfo("Unknown VDR (~p) MSG ID (~p), MSG Index (~p), MSG Tel (~p)~n", [NewState#vdritem.addr, ID, MsgIdx, Tel]),
                    case ID of
                        16#100 ->
                            % Not complete
                            % Register VDR
                            %{Province, City, Producer, TermModel, TermID, LicColor, LicID} = Msg,
                            case create_sql_from_vdr(HeadInfo, Msg, NewState) of
                                {ok, Sql} ->
                                    %SqlResp = send_sql_to_db(regauth, Sql, State),
                                    SqlResp = send_sql_to_db(conn, Sql, NewState),
                                    % 0 : ok
                                    % 1 : vehicle registered
                                    % 2 : no such vehicle in DB
                                    % 3 : VDR registered
                                    % 4 : no such VDR in DB
                                    case extract_db_resp(SqlResp) of
                                        {ok, empty} -> % No vehicle and no VDR. However, only reply no vehicle here.
                                            FlowIdx = NewState#vdritem.msgflownum,
                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 2, empty),
                                            common:logerror("~p sends VDR (~p) registration response (no such vechile in DB) : ~p~n", [NewState#vdritem.pid, State#vdritem.addr, MsgBody]),
                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                            
                                            % return error to terminate VDR connection
                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}};
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
                                            {<<"vehicle">>, <<"code">>, _VehicleCode} = get_record_field(<<"vehicle">>, Rec, <<"code">>),
                                            {<<"vehicle">>, <<"device_id">>, VehicleDeviceID} = get_record_field(<<"vehicle">>, Rec, <<"device_id">>),
                                            {<<"vehicle">>, <<"dev_install_time">>, VehicleDeviceInstallTime} = get_record_field(<<"vehicle">>, Rec, <<"dev_install_time">>),
                                            if
                                                VehicleID == undefined orelse DeviceID == undefined -> % No vehicle or no VDR
                                                    if
                                                        VehicleID == undefined ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 2, empty),
                                                            common:logerror("~p sends VDR (~p) registration response (no such vechile in DB) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true -> % DeviceID == undefined ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 4, empty),
                                                            common:logerror("~p sends VDR (~p) registration response (no such VDR in DB) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}}
                                                    end;
                                                VehicleDeviceID =/= undefined andalso DeviceVehicleID =/= undefined -> % Vehicle registered and VDR registered
                                                    if
                                                        VehicleDeviceID =/= DeviceID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 1, empty),
                                                            common:logerror("~p sends VDR (~p) registration response (vehicle registered) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        DeviceVehicleID =/= VehicleID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 3, empty),
                                                            common:logerror("~p sends VDR (~p) registration response (VDR registered) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
															case is_binary(DeviceAuthenCode) of
																true ->
		                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, DeviceAuthenCode),
		                                                            %common:loginfo("~p sends VDR registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, VehicleCode, MsgBody]),
		                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
		                                                            
		                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        
		                                                            
		                                                            % return error to terminate VDR connection
		                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[], alarm=0, alarmlist=[], state=0, statelist=[], tel=Tel}};
																false ->
		                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
		                                                            %common:loginfo("~p sends VDR registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, VehicleCode, MsgBody]),
		                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
		                                                            
		                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        
		                                                            
		                                                            % return error to terminate VDR connection
		                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[], tel=Tel}}
															end
                                                    end;
                                                VehicleDeviceID =/= undefined andalso DeviceVehicleID == undefined -> % Vehicle registered
                                                    if
                                                        VehicleDeviceID =/= DeviceID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 1, empty),
                                                            common:logerror("~p sends VDR (~p) registration response (vehicle registered) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true ->
                                                            VDRVehicleIDSql = list_to_binary([<<"update device set vehicle_id='">>,
                                                                                              common:integer_to_binary(VehicleID),
                                                                                              <<"' where id=">>,
                                                                                              common:integer_to_binary(DeviceID)]),
                                                            % Should we check the update result?
                                                            send_sql_to_db_nowait(conn, VDRVehicleIDSql, NewState),
                                                            
                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        

                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
                                                            %common:loginfo("~p sends VDR (~p) registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, VehicleCode, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[], alarm=0, alarmlist=[], state=0, statelist=[], tel=Tel}}
                                                    end;
                                                VehicleDeviceID == undefined andalso DeviceVehicleID =/= undefined -> % Vehicle registered
                                                    if
                                                        DeviceVehicleID =/= VehicleID ->
                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 3, empty),
                                                            common:logerror("~p sends VDR (~p) registration response (VDR registered) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                            
                                                            % return error to terminate VDR connection
                                                            {error, regerror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                                        true ->
                                                            VehicleVDRIDSql = list_to_binary([<<"update vehicle set device_id='">>,
                                                                                              common:integer_to_binary(DeviceID),
                                                                                              <<"' where id=">>,
                                                                                              common:integer_to_binary(VehicleID)]),
                                                            send_sql_to_db_nowait(conn, VehicleVDRIDSql, NewState),
                                                            
                                                            update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),        

                                                            FlowIdx = NewState#vdritem.msgflownum,
                                                            MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
                                                            %common:loginfo("~p sends VDR (~p) registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, VehicleCode, MsgBody]),
                                                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),

                                                            % return error to terminate VDR connection
                                                            {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[], alarm=0, alarmlist=[], state=0, statelist=[], tel=Tel}}
                                                    end;
                                                VehicleDeviceID == undefined andalso DeviceVehicleID == undefined ->
                                                    VDRVehicleIDSql = list_to_binary([<<"update device set vehicle_id='">>,
                                                                                      common:integer_to_binary(VehicleID),
                                                                                      <<"' where id=">>,
                                                                                      common:integer_to_binary(DeviceID)]),
                                                    send_sql_to_db_nowait(conn, VDRVehicleIDSql, NewState),
                                                    
                                                    VehicleVDRIDSql = list_to_binary([<<"update vehicle set device_id='">>,
                                                                                      common:integer_to_binary(DeviceID),
                                                                                      <<"' where id=">>,
                                                                                      common:integer_to_binary(VehicleID)]),
                                                    send_sql_to_db_nowait(conn, VehicleVDRIDSql, NewState),

                                                    update_reg_install_time(DeviceID, DeviceRegTime, VehicleID, VehicleDeviceInstallTime, NewState),      

                                                    FlowIdx = NewState#vdritem.msgflownum,
                                                    MsgBody = vdr_data_processor:create_reg_resp(MsgIdx, 0, list_to_binary(DeviceAuthenCode)),
                                                    %common:loginfo("~p sends VDR (~p) registration response (ok) (vehicle code : ~p) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, VehicleCode, MsgBody]),
                                                    NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),
                                                    
                                                    {ok, NewState#vdritem{msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[], alarm=0, alarmlist=[], state=0, statelist=[], tel=Tel}};
                                                true -> % Impossible condition
                                                    {error, regerror, NewState}
                                            end;
                                        _ ->
                                            % 
                                            {error, regerror, NewState}
                                    end;
                                _ ->
                                    {error, regerror, NewState}
                            end;
                        16#102 ->
                            % VDR Authentication
                            case create_sql_from_vdr(HeadInfo, Msg, NewState) of
                            %Sql = "select * from device,vehicle where device.serial_no='abcdef' and vehicle.device_id=device.id",
                            %case {ok, Sql} of
                                {ok, Sql} ->
                                    %SqlResp = send_sql_to_db(regauth, Sql, State),
                                    SqlResp = send_sql_to_db(conn, Sql, NewState),
									%common:loginfo("SQL : ~p~nSQL Result : ~p", [Sql, SqlResp]),
                                    case extract_db_resp(SqlResp) of
                                        {ok, empty} ->
                                            {error, autherror, NewState};
                                        {ok, [Rec]} ->
                                            % "id" is NOT NULL & UNIQUE, so it cannot be null. However it can be undefined because vehicle table device_id may don't be euqual to device table id 
                                            {<<"vehicle">>, <<"code">>, VehicleCode} = get_record_field(<<"vehicle">>, Rec, <<"code">>),
											if
												VehicleCode =/= undefined andalso binary_part(VehicleCode, 0, 1) == <<"?">> ->
													common:logerror("VDR (~p) Vehicle Code has invalid character \"?\" and will be disconnected : ~p~n", [State#vdritem.addr, VehicleCode]),
													{error, charerror, NewState};
												true ->
													{VDRID, VDRSerialNo, VDRAuthenCode, VehicleID, DriverID} = get_record_column_info(Rec),
		                                            if
		                                                VehicleID == undefined orelse VehicleCode==undefined ->
		                                                    {error, autherror, NewState};
		                                                true ->
															disconn_socket_by_vehicle_id(VehicleID),
		                                                    SockVdrList = ets:lookup(vdrtable, Socket),
		                                                    case length(SockVdrList) of
		                                                        1 ->
		                                                            % "authen_code" is the query condition, so Auth should be equal to VDRAuthEnCode
		                                                            %{Auth} = Msg,
		                                                            
		                                                            %SqlUpdate = list_to_binary([<<"update device set is_online=1 where authen_code='">>, VDRAuthenCode, <<"'">>]),
		                                                            %SqlUpdate = list_to_binary([<<"replace into device(authen_code,is_online) values('">>, VDRAuthenCode, <<"',1)">>]),
		                                                            %send_sql_to_db(conn, SqlUpdate, NewState),

																	SqlAlarmList = list_to_binary([<<"select * from vehicle_alarm where vehicle_id=">>, common:integer_to_binary(VehicleID), <<" and isnull(clear_time)">>]),
																	SqlAlarmListResp = send_sql_to_db(conn, SqlAlarmList, NewState),
																	case extract_db_resp(SqlAlarmListResp) of
																		{ok, empty} ->
																			%common:loginfo("Original AlarmList : []~n"),	
				                                                            case wsock_data_parser:create_term_online([VehicleID]) of
				                                                                {ok, WSUpdate} ->
				                                                                    %common:loginfo("VDR (~p) WS : ~p~n~p~n", [State#vdritem.addr, WSUpdate, list_to_binary(WSUpdate)]),
				                                                                    send_msg_to_ws(WSUpdate, NewState),
				                                                            
				                                                                    FlowIdx = NewState#vdritem.msgflownum,
				                                                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
				                                                                    %common:loginfo("~p sends VDR (~p) response for 16#102 (ok) : ~p~n", [State#vdritem.pid, State#vdritem.addr, MsgBody]),
				                                                                    NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),
																				
																					FinalState = NewState#vdritem{id=VDRID, 
				                                                                                                  serialno=binary_to_list(VDRSerialNo),
				                                                                                                  auth=binary_to_list(VDRAuthenCode),
				                                                                                                  vehicleid=VehicleID,
				                                                                                                  vehiclecode=binary_to_list(VehicleCode),
																									              driverid=DriverID,
				                                                                                                  msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[],
																									              alarm=0, alarmlist=[], state=0, statelist=[], tel=Tel},
                                                                                    VDRTablePid = NewState#vdritem.vdrtablepid,
                                                                                    common:send_vdr_table_operation(VDRTablePid, {self(), insert, FinalState, noresp}),
				                                        
																					{ok, FinalState};
				                                                                _ ->
				                                                                    {error, autherror, NewState}
				                                                            end;
																		{ok, Reses} ->
																			% Initialize the alarm list immediately after auth
																			AlarmList = get_alarm_list(Reses),
																			%common:loginfo("Original AlarmList : ~p~n", [AlarmList]),		                                                            
				                                                            case wsock_data_parser:create_term_online([VehicleID]) of
				                                                                {ok, WSUpdate} ->
				                                                                    %common:loginfo("VDR (~p) WS : ~p~n~p~n", [State#vdritem.addr, WSUpdate, list_to_binary(WSUpdate)]),
				                                                                    send_msg_to_ws(WSUpdate, NewState),
																					
				                                                                    FlowIdx = NewState#vdritem.msgflownum,
				                                                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
				                                                                    %common:loginfo("~p sends VDR (~p) response for 16#102 (ok) : ~p~n", [NewState#vdritem.pid, NewState#vdritem.addr, MsgBody]),
				                                                                    NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),
				                                        
																					FinalState = NewState#vdritem{id=VDRID,
				                                                                                                  serialno=binary_to_list(VDRSerialNo),
				                                                                                                  auth=binary_to_list(VDRAuthenCode),
				                                                                                                  vehicleid=VehicleID,
				                                                                                                  vehiclecode=binary_to_list(VehicleCode),
																									              driverid=DriverID,
				                                                                                                  msgflownum=NewFlowIdx, msg2vdr=[], msg=[], req=[],
																									              alarm=0, alarmlist=AlarmList, state=0, statelist=[], tel=Tel},
                                                                                    VDRTablePid = NewState#vdritem.vdrtablepid,
                                                                                    common:send_vdr_table_operation(VDRTablePid, {self(), insert, FinalState, noresp}),
																					
				                                                                    {ok, FinalState};
				                                                                _ ->
				                                                                    {error, autherror, NewState}
				                                                            end
																	end;
		                                                        _ ->
		                                                            % vdrtable error
		                                                            {error, autherror, NewState}
		                                                    end
		                                            end
											end;
                                        _ ->
                                            % DB includes no record with the given authen_code
                                            {error, autherror, NewState}
                                    end;
                                _ ->
                                    % Authentication fails
                                    {error, autherror, NewState}
                            end;
                        true ->
                            common:logerror("Invalid common message from unknown/unregistered/unauthenticated VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) MSG ID : ~p~n", [NewState#vdritem.addr, NewState#vdritem.id, NewState#vdritem.serialno, NewState#vdritem.auth, NewState#vdritem.vehicleid, NewState#vdritem.vehiclecode, ID]),
                            % Unauthorized/Unregistered VDR can only accept 16#100/16#102
                            {error, unautherror, State}
                    end;
                true ->
					VDRPid = State#vdritem.vdrpid,
					%common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) MSG ID (~p), MSG Index (~p), MSG Tel (~p)~n",
					%			   [NewState#vdritem.addr, 
					%				NewState#vdritem.id, 
					%				NewState#vdritem.serialno, 
					%				NewState#vdritem.auth, 
					%				NewState#vdritem.vehicleid, 
					%				NewState#vdritem.vehiclecode, 
					%				ID, MsgIdx, Tel]),
                    case ID of
                        16#1 ->     % VDR general response
                            {RespFlowIdx, RespID, Res} = Msg,
                            
                            % Process reponse from VDR here
                            common:loginfo("Gateway (~p) receives VDR (~p) general response (16#1) : RespFlowIdx (~p), RespID (~p), Res (~p)~n", [State#vdritem.pid, State#vdritem.addr, RespFlowIdx, RespID, Res]),
                            
                            if
                                %RespID == 16#8003 orelse
									RespID == 16#8103 orelse
									RespID == 16#8203 orelse	% has issue
									RespID == 16#8600 orelse	% need further tested
									RespID == 16#8601 orelse
									RespID == 16#8602 orelse	% need further tested
									RespID == 16#8603 orelse
									RespID == 16#8604 orelse	% need further tested
									RespID == 16#8605 orelse
									RespID == 16#8606 orelse	% need further tested
									RespID == 16#8607 orelse
									RespID == 16#8105 orelse
									RespID == 16#8108 orelse
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
                                            %common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, RespID, WSUpdate]),
                                            send_msg_to_ws(WSUpdate, NewState);
                                        ItemCount ->
                                            common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, RespID])
                                    end,
                                    
                                    NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= RespID],
                                    VDRTablePid = VDRItem#vdritem.vdrtablepid,
                                    NewVDRItem = VDRItem#vdritem{msgws2vdr=NewMsgList},
                                    common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                                    
                                    {ok, NewState#vdritem{msgws2vdr=NewMsgList}};
                                true ->
                                    {ok, NewState}
                            end;
                        16#2 ->     % VDR pulse
                            % Nothing to do here
                            %{} = Msg,
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            %common:loginfo("Gateway (~p) sends VDR (~p) response for 16#2 (Pulse) : ~p~n", [State#vdritem.pid, State#vdritem.addr, MsgBody]),
                            NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),

                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        16#3 ->     % VDR unregistration
                            %{} = Msg,
                            Auth = NewState#vdritem.auth,
                            ID = NewState#vdritem.id,
                            case create_sql_from_vdr(HeadInfo, {ID, Auth}, NewState) of
                                {ok, Sql} ->
                                    send_sql_to_db_nowait(conn, Sql, NewState),
        
                                    FlowIdx = NewState#vdritem.msgflownum,
                                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                                    %common:loginfo("~p sends VDR (~p) response for 16#3 (Position) : ~p~n", [State#vdritem.pid, NewState#vdritem.addr, MsgBody]),
                                    NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),
        
                                    % return error to terminate connection with VDR
                                    {error, exiterror, NewState#vdritem{msgflownum=NewFlowIdx}};
                                _ ->
                                    {error, vdrerror, NewState}
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
							process_pos_info(ID, MsgIdx, VDRPid, HeadInfo, Msg, NewState);
                        16#201 ->
                            case Msg of
								{_RespFlowIdx, PosInfo} ->
		                            process_pos_info(ID, MsgIdx, VDRPid, HeadInfo, PosInfo, NewState);
								_ ->
									{error, vdrerror, NewState}
							end;
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
                                    %common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, 16#8302, WSUpdate]),
                                    send_msg_to_ws(WSUpdate, NewState);
                                ItemCount ->
                                    common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, 16#8302])
                            end,
                                    
                            NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= 16#8302],
                            VDRTablePid = VDRItem#vdritem.vdrtablepid,
                            NewVDRItem = VDRItem#vdritem{msgws2vdr=NewMsgList},
                            common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                            
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
                                    %common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, 16#8500, WSUpdate]),
                                    send_msg_to_ws(WSUpdate, NewState);
                                ItemCount ->
                                    common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, 16#8500])
                            end,
                                    
                            NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= 16#8500],
                            VDRTablePid = VDRItem#vdritem.vdrtablepid,
                            NewVDRItem = VDRItem#vdritem{msgws2vdr=NewMsgList},
                            common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                            
                            {ok, NewState#vdritem{msgws2vdr=NewMsgList}};
                        16#700 ->
                            {_Number, _OrderWord, _DB} = Msg,
                            
                            {ok, NewState};
                        16#701 ->
                            {_Length, _Content} = Msg,
                            
                            {ok, NewState};
                        16#702 ->
                            %{_DrvState, _Time, _IcReadResult, _NameLen, _N, _C, _OrgLen, _O, _Validity} = Msg,
                            case create_sql_from_vdr(HeadInfo, Msg, NewState) of
								{ok, Sql} ->
									send_sql_to_db_nowait(conn, Sql, NewState),
                                                        
		                            FlowIdx = NewState#vdritem.msgflownum,
		                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
		                            %common:loginfo("~p sends VDR driver info update response (ok) : ~p~n", [NewState#vdritem.pid, MsgBody]),
		                            NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),
		
									%{ok, NewState};
		                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
 								_ ->
									{error, vdrerror, NewState}
							end;								
                        16#704 ->
                            {_Len, _Type, _Positions} = Msg,
                            
                            {ok, NewState};
                        16#705 ->
                            {_Count, _Time, _Data} = Msg,
                            
                            {ok, NewState};
                        16#800 ->
							{_MsgId, _MsgType, _MsgCode, _MsgEICode, _MsgPipeId} = Msg,
							
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),

                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        16#801 ->
							{MediaId, _Type, _Code, _EICode, _PipeId, _PosInfo, _Pack} = Msg,
                            case create_sql_from_vdr(HeadInfo, Msg, NewState) of
                                {ok, Sqls} ->
                                    send_sqls_to_db_nowait(conn, Sqls, NewState),

		                            FlowIdx = NewState#vdritem.msgflownum,
									MsgBody = vdr_data_processor:create_multimedia_data_reply(MediaId),
		                            NewFlowIdx = send_data_to_vdr(16#8800, Tel, FlowIdx, MsgBody, NewState),
									
						            [VDRItem] = ets:lookup(vdrtable, Socket),
                                    VDRTablePid = VDRItem#vdritem.vdrtablepid,
                                    NewVDRItem = VDRItem#vdritem{msg=NewState#vdritem.msg},
                                    common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
									
		                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
								_ ->
									{error, vdrerror, NewState}
							end;								
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
                                    %common:loginfo("Gateway receives VDR (~p) response to WS request ~p : ~p~n", [NewState#vdritem.addr, 16#8801, WSUpdate]),
                                    send_msg_to_ws(WSUpdate, NewState);
                                ItemCount ->
                                    common:logerror("(FATAL) vdritem.msgws2vdr has ~p item(s) for wsid ~p~n", [ItemCount, 16#8801])
                            end,
                                    
                            NewMsgList = [{WSID, WSFlowIdx, WSValue} || {WSID, WSFlowIdx, WSValue} <- MsgList, WSID =/= 16#8801],
                            VDRTablePid = VDRItem#vdritem.vdrtablepid,
                            NewVDRItem = VDRItem#vdritem{msgws2vdr=NewMsgList},
                            common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                            
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
                            NewFlowIdx = send_data_to_vdr(16#8100, Tel, FlowIdx, MsgBody, NewState),

                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        16#102 ->
                            FlowIdx = NewState#vdritem.msgflownum,
                            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                            NewFlowIdx = send_data_to_vdr(16#8001, Tel, FlowIdx, MsgBody, NewState),
                            
                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        _ ->
                            common:loginfo("Invalid message from registered/authenticated VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p) MSG ID : ~p~n", 
										   [NewState#vdritem.addr, 
											NewState#vdritem.id, 
											NewState#vdritem.serialno, 
											NewState#vdritem.auth, 
											NewState#vdritem.vehicleid, 
											NewState#vdritem.vehiclecode, 
											ID]),
                            {error, invalidmsgerror, NewState}
                    end
            end;
        {ignore, HeaderInfo, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
    		NewFlowIdx = send_data_to_vdr(16#8001, NewState#vdritem.tel, FlowIdx, MsgBody, NewState),
            {RequiredId, MsgPackages} = NewState#vdritem.msgpackages,
            if
                RequiredId > -1 ->
                    common:loginfo("~p starts sending VDR (~p) request for resend : required msg id ~p~n", 
								   [NewState#vdritem.pid, 
									NewState#vdritem.addr, 
									RequiredId]),
                    MissingMsgIdx = find_missing_msgidx(RequiredId, MsgPackages),
                    common:loginfo("~p starts sending VDR (~p) request for resend : finding missing msg index ~p~n", 
								   [NewState#vdritem.pid, 
									NewState#vdritem.addr, 
									MissingMsgIdx]),
                    case MissingMsgIdx of
                        none ->
                            [VDRItem] = ets:lookup(vdrtable, Socket),
                            VDRTablePid = VDRItem#vdritem.vdrtablepid,
                            NewVDRItem = VDRItem#vdritem{msg=NewState#vdritem.msg},
                            common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                            
                            {ok, NewState#vdritem{msgflownum=NewFlowIdx}};
                        {FirstmsgIdxID, MsgIdxsID} ->
                            MsgBody1 = vdr_data_processor:create_resend_subpack_req(FirstmsgIdxID, length(MsgIdxsID), MsgIdxsID),
                            common:loginfo("~p sends VDR (~p) request for resend : fisrt msg id ~p, msg indexes ~p~n~p~n", 
										   [NewState#vdritem.pid, 
											NewState#vdritem.addr, 
											FirstmsgIdxID, 
											MsgIdxsID, 
											MsgBody1]),
                            NewFlowIdx1 = send_data_to_vdr(16#8003, NewState#vdritem.tel, FlowIdx, MsgBody1, NewState),

                            [VDRItem] = ets:lookup(vdrtable, Socket),
                            VDRTablePid = VDRItem#vdritem.vdrtablepid,
                            NewVDRItem = VDRItem#vdritem{msg=NewState#vdritem.msg},
                            common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                            
                            {ok, NewState#vdritem{msgflownum=NewFlowIdx1}}
                    end;
                true ->
                    [VDRItem] = ets:lookup(vdrtable, Socket),
                    VDRTablePid = VDRItem#vdritem.vdrtablepid,
                    NewVDRItem = VDRItem#vdritem{msg=NewState#vdritem.msg},
                    common:send_vdr_table_operation(VDRTablePid, {self(), insert, NewVDRItem, noresp}),
                    
                    {ok, NewState#vdritem{msgflownum=NewFlowIdx}}
			end;
        {warning, HeaderInfo, ErrorType, NewState} ->
            {ID, MsgIdx, _Tel, _CryptoType} = HeaderInfo,
            FlowIdx = NewState#vdritem.msgflownum,
            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ErrorType),
			if
				NewState#vdritem.vdrpid == undefined ->
            		NewFlowIdx = send_data_to_vdr(16#8001, NewState#vdritem.tel, FlowIdx, MsgBody, NewState),
					{warning, NewState#vdritem{msgflownum=NewFlowIdx}};
				true ->
					NewFlowIdx = send_data_to_vdr(16#8001, NewState#vdritem.tel, FlowIdx, MsgBody, NewState),
					{warning, NewState#vdritem{msgflownum=NewFlowIdx}}
			end;
        {error, _ErrorType, NewState} ->    % exception/parityerror/formaterror
            {error, unvdrerror, NewState}
    end.

get_record_column_info(Record) ->
	% "id" is PK, so it cannot be null or empty
    {<<"device">>, <<"id">>, VDRID} = get_record_field(<<"device">>, Record, <<"id">>),
    % "serial" is NOT NULL & UNIQUE, so it cannot be null or undefined
    {<<"device">>, <<"serial_no">>, VDRSerialNo} = get_record_field(<<"device">>, Record, <<"serial_no">>),
    % "authen_code" is NOT NULL & UNIQUE, so it cannot be null or undefined
    {<<"device">>, <<"authen_code">>, VDRAuthenCode} = get_record_field(<<"device">>, Record, <<"authen_code">>),
    % "id" is PK, so it cannot be null. However it can be undefined because vehicle table device_id may don't be euqual to device table id 
    {<<"vehicle">>, <<"id">>, VehicleID} = get_record_field(<<"vehicle">>, Record, <<"id">>),
    {<<"vehicle">>, <<"driver_id">>, DriverID} = get_record_field(<<"vehicle">>, Record, <<"driver_id">>),
	{VDRID, VDRSerialNo, VDRAuthenCode, VehicleID, DriverID}.

find_missing_msgidx(RequiredId, MsgPackages) when is_integer(RequiredId),
                                                  RequiredId > -1,
                                                  is_list(MsgPackages),
                                                  length(MsgPackages) > 0 ->
    [H|T] = MsgPackages,
    [HId, HFirstmsgIdx, HMsgIdxs] = H,
    if
        HId == RequiredId ->
            {HFirstmsgIdx, HMsgIdxs};
        true ->
    		find_missing_msgidx(RequiredId, T)
    end;
find_missing_msgidx(_RequiredId, _MsgPackages) ->
    none.

create_time_list_and_binary(Time) when is_integer(Time) ->
    <<Year:8, Month:8, Day:8, Hour:8, Minute:8, Second:8>> = <<Time:48>>,
    YearBin = common:integer_to_binary(common:convert_bcd_integer(Year)),
    MonthBin = common:integer_to_binary(common:convert_bcd_integer(Month)),
    DayBin = common:integer_to_binary(common:convert_bcd_integer(Day)),
    HourBin = common:integer_to_binary(common:convert_bcd_integer(Hour)),
    MinuteBin = common:integer_to_binary(common:convert_bcd_integer(Minute)),
    SecondBin = common:integer_to_binary(common:convert_bcd_integer(Second)),
	TimeBin = list_to_binary([YearBin, <<"-">>, MonthBin, <<"-">>, DayBin, <<" ">>, HourBin, <<":">>, MinuteBin, <<":">>, SecondBin]),
	TimeList = binary_to_list(TimeBin),
	{TimeBin, TimeList};
create_time_list_and_binary(_Time) ->
	{<<"2000-01-01 00:00:00">>, "2000-01-01 00:00:00"}.

process_pos_info(ID, MsgIdx, _VDRPid, HeadInfo, Msg, NewState) ->
    case create_sql_from_vdr(HeadInfo, Msg, NewState) of
		{ok, Sqls} ->
            send_sqls_to_db_nowait(conn, Sqls, NewState),
            
            FlowIdx = NewState#vdritem.msgflownum,
            PreviousAlarm = NewState#vdritem.alarm,
            
            {H, _AppInfo} = Msg,
            [AlarmSym, StateFlag, LatOri, LonOri, _Height, _Speed, _Direction, Time]= H,
            {Lat, Lon} = get_not_0_lat_lon(LatOri, LonOri, NewState),
            if
                AlarmSym == PreviousAlarm ->
		            MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
		            NewFlowIdx = send_data_to_vdr(16#8001, NewState#vdritem.tel, FlowIdx, MsgBody, NewState),
					
					{ok, NewState#vdritem{msgflownum=NewFlowIdx, alarm=AlarmSym, state=StateFlag, lastlat=Lat, lastlon=Lon}};
                true ->
					{TimeBin, TimeS} = create_time_list_and_binary(Time),
                    TimeBinS = list_to_binary([<<"\"">>, TimeBin, <<"\"">>]),
					
					AlarmList = update_vehicle_alarm(NewState#vdritem.vehicleid, NewState#vdritem.driverid, TimeS, AlarmSym, 0, NewState),
					if
						AlarmList == NewState#vdritem.alarmlist ->
							ok;
						AlarmList =/= NewState#vdritem.alarmlist ->
							NewSetAlarmList = find_alarm_in_lista_not_in_listb(AlarmList, NewState#vdritem.alarmlist),
							NewClearAlarmList = find_alarm_in_lista_not_in_listb(NewState#vdritem.alarmlist, AlarmList),
							
							send_masg_to_ws_alarm(FlowIdx, NewSetAlarmList, 1, Lat, Lon, TimeBinS, NewState),
							send_masg_to_ws_alarm(FlowIdx, NewClearAlarmList, 0, Lat, Lon, TimeBinS, NewState)
					end,

                    MsgBody = vdr_data_processor:create_gen_resp(ID, MsgIdx, ?T_GEN_RESP_OK),
                    NewFlowIdx = send_data_to_vdr(16#8001, NewState#vdritem.tel, FlowIdx, MsgBody, NewState),
                    
                    {ok, NewState#vdritem{msgflownum=NewFlowIdx, alarm=AlarmSym, alarmlist=AlarmList, state=StateFlag, lastlat=Lat, lastlon=Lon}}
            end;
        _ ->
            {error, invaliderror, NewState}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% SetClear : 1 or 0
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_masg_to_ws_alarm(FlowIdx, AlarmList, SetClear, Lat, Lon, TimeBinS, State) when is_list(AlarmList),
												                                    length(AlarmList) > 0,
														                            is_binary(TimeBinS) ->
	[H|T] = AlarmList,
	LenT = length(T),
	{ID, _Time} = H,
	case SetClear of
		1 ->
            {ok, WSUpdate} = wsock_data_parser:create_term_alarm([State#vdritem.vehicleid],
                                                                 FlowIdx,
                                                                 common:combine_strings(["\"", State#vdritem.vehiclecode, "\""], false),
                                                                 ID,
                                                                 1,
                                                                 Lat, 
                                                                 Lon,
                                                                 binary_to_list(TimeBinS)),
            send_msg_to_ws(WSUpdate, State), %wsock_client:send(WSUpdate)
			if
				LenT > 0 ->
					send_masg_to_ws_alarm(FlowIdx, T, SetClear, Lat, Lon, TimeBinS, State);
				true ->
					ok
			end;
		0 ->
            {ok, WSUpdate} = wsock_data_parser:create_term_alarm([State#vdritem.vehicleid],
                                                                 FlowIdx,
                                                                 common:combine_strings(["\"", State#vdritem.vehiclecode, "\""], false),
                                                                 ID,
                                                                 0,
                                                                 Lat, 
                                                                 Lon,
                                                                 binary_to_list(TimeBinS)),
            send_msg_to_ws(WSUpdate, State), %wsock_client:send(WSUpdate)
			if
				LenT > 0 ->
					send_masg_to_ws_alarm(FlowIdx, T, SetClear, Lat, Lon, TimeBinS, State);
				true ->
					ok
			end;
		_ ->
			ok
	end;
send_masg_to_ws_alarm(_FlowIdx, _AlarmList, _SetClear, _Lat, _Lon, _TimeBinS, _State) ->
	ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
find_alarm_in_lista_not_in_listb(ListA, ListB) when is_list(ListA),
			        								is_list(ListB)->
	LenA = length(ListA),
	LenB = length(ListB),
	if
		LenA < 1 ->
			[];
		true ->
			if
				LenB < 1 ->
					ListA;
				true ->
					[H|T] = ListA,
					case find_a_in_lista(ListB, H) of
						true ->
							find_alarm_in_lista_not_in_listb(T, ListB);
						false ->
							lists:merge([[H], find_alarm_in_lista_not_in_listb(T, ListB)])
					end
			end
	end;
find_alarm_in_lista_not_in_listb(_ListA, _ListB) ->
	[].
					
find_a_in_lista(ListA, A) when is_list(ListA),
							   length(ListA) > 0 ->
	[H|T] = ListA,
	{ID, _Time} = H,
	{IDA, _TimeA} = A,
	if
		ID == IDA ->
			true;
		true ->
			LenT = length(T),
			if
				LenT < 1 ->
					false;
				true ->
					find_a_in_lista(T, A)
			end
	end;
find_a_in_lista(_ListA, _A) ->
	false.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Return	: [{ID0, "YY-MM-DD hh:mm:ss"}, {ID1, "YY-MM-DD hh:mm:ss"}, ...]
% 			"YY-MM-DD hh:mm:ss" is alarm time.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
            send_sql_to_db_nowait(conn, DevInstallTimeSql, State);
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
            send_sql_to_db_nowait(conn, VDRRegTimeSql, State);
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
	if
		BitState == 1 ->
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    UpdateSql = list_to_binary([<<"insert into vehicle_alarm(vehicle_id,driver_id,alarm_time,clear_time,type_id) values(">>,
                                                common:integer_to_binary(VehicleID), <<",">>,
                                                common:integer_to_binary(DriverID), <<",'">>,
                                                list_to_binary(TimeS), <<"',NULL,">>,
                                                common:integer_to_binary(Index), <<")">>]),
                    send_sql_to_db_nowait(conn, UpdateSql, State),
                    NewAlarmList = lists:merge(AlarmList,[{Index, TimeS}]),
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State#vdritem{alarmlist=NewAlarmList});
                true ->
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State)
            end;
		true ->
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    update_vehicle_alarm(VehicleID, DriverID, TimeS, Alarm, Index+1, State);
                true ->
                    {Index, SetTime} = AlarmEntry,
                    UpdateSql = list_to_binary([<<"update vehicle_alarm set clear_time='">>, list_to_binary(TimeS),
                                                <<"' where vehicle_id=">>, common:integer_to_binary(VehicleID),
                                                <<" and driver_id=">>, common:integer_to_binary(DriverID),
                                                <<" and alarm_time='">>, list_to_binary(SetTime),
                                                <<"' and type_id=">>, common:integer_to_binary(Index)]),
                    send_sql_to_db_nowait(conn, UpdateSql, State),
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
    if
        BitState == Flag ->
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    UpdateSql = list_to_binary([<<"insert into vehicle_alarm(vehicle_id,driver_id,alarm_time,clear_time,type_id) values(">>,
                                                common:integer_to_binary(VehicleID), <<",0,'">>,
                                                list_to_binary(TimeS), <<"',NULL,">>,
                                                common:integer_to_binary(Index), <<")">>]),
                    send_sql_to_db_nowait(conn, UpdateSql, State),
                    NewAlarmList = lists:merge(AlarmList,[{Index, TimeS}]),
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State#vdritem{alarmlist=NewAlarmList});
                true ->
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State)
            end;
        true ->
            AlarmEntry = get_alarm_item(Index, AlarmList),
            if
                AlarmEntry == empty ->
                    update_vehicle_alarm(VehicleID, _DriverID, TimeS, Alarm, Index+1, State);
                true ->
                    {Index, SetTime} = AlarmEntry,
                    UpdateSql = list_to_binary([<<"update vehicle_alarm set clear_time='">>, list_to_binary(TimeS),
                                                <<"' where vehicle_id=">>, common:integer_to_binary(VehicleID),
                                                <<" and driver_id=0 and alarm_time='">>, list_to_binary(SetTime),
                                                <<"' and type_id=">>, common:integer_to_binary(Index)]),
                    send_sql_to_db_nowait(conn, UpdateSql, State),
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
			vdr_server:terminate_invalid_vdrs(Sock),
            disconn_socket_by_id(T)
    end;
disconn_socket_by_id(_SockList) ->
    ok.

disconn_socket_by_vehicle_id(VehicleID) ->
	SockList = ets:match(vdrtable, {'_', 
	                     '$1', '_', '_', '_', VehicleID,
	                     '_', '_', '_', '_', '_',
	                     '_', '_', '_', '_', '_',
	                     '_', '_', '_', '_', '_',
	                     '_', '_', '_', '_', '_',
                         '_', '_', '_', '_', '_',
                         '_', '_', '_', '_'}),
	disconn_socket_by_id(SockList).

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
send_data_to_vdr(ID, Tel, FlowIdx, MsgBody, State) ->
	VDRPid = State#vdritem.vdrpid,
	Socket = State#vdritem.socket,
	Pid = State#vdritem.pid,
	LinkPid = State#vdritem.linkpid,
	case is_binary(MsgBody) of
		true ->
			MsgLen = byte_size(MsgBody),
			if
				MsgLen > 24 ->
					Header = binary:part(MsgBody, 0, 20),
					if
						Header == ?SUB_PACK_INDI_HEADER ->
							Total = binary:part(MsgBody, 20, 2),
							<<TotalInt:16>> = Total,
							Index = binary:part(MsgBody, 22, 2),
							<<IndexInt:16>> = Index,
							Tail = binary:part(MsgBody, 24, MsgLen-24),
							Msg = vdr_data_processor:create_final_msg(ID, Tel, FlowIdx, Tail, TotalInt, IndexInt),
							do_send_data_to_vdr(VDRPid, Pid, Socket, Msg, ID, FlowIdx, LinkPid);
						true ->
				            Msg = vdr_data_processor:create_final_msg(ID, Tel, FlowIdx, MsgBody),
							do_send_data_to_vdr(VDRPid, Pid, Socket, Msg, ID, FlowIdx, LinkPid)
					end;
				true ->
		            Msg = vdr_data_processor:create_final_msg(ID, Tel, FlowIdx, MsgBody),
					do_send_data_to_vdr(VDRPid, Pid, Socket, Msg, ID, FlowIdx, LinkPid)
			end;
		_ ->
            Msg = vdr_data_processor:create_final_msg(ID, Tel, FlowIdx, MsgBody),
			do_send_data_to_vdr(VDRPid, Pid, Socket, Msg, ID, FlowIdx, LinkPid)
    end.

do_send_data_to_vdr(VDRPid, Pid, Socket, Msg, ID, FlowIdx, LinkPid) ->
	case is_list(Msg) of
		true ->
			do_send_msg2vdr(VDRPid, Pid, Socket, Msg, LinkPid);
		_ ->
			case is_binary(Msg) of
				true ->
					if
						Msg == <<>> andalso ID =/= 16#8702 ->
							common:logerror("~p send_data_to_vdr NULL final message : ID (~p), FlowIdx (~p), Msg (~p)~n", [Pid, ID, FlowIdx, Msg]);
						Msg == <<>> andalso ID == 16#8702 ->
							do_send_msg2vdr(VDRPid, Pid, Socket, Msg, LinkPid),
							get_new_flow_index(FlowIdx);
						Msg =/= <<>> ->
							do_send_msg2vdr(VDRPid, Pid, Socket, Msg, LinkPid),
							get_new_flow_index(FlowIdx)
					end;
				_ ->
					FlowIdx
			end
	end.

get_new_flow_index(FlowIdx) ->
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
	end.

do_send_msg2vdr(VDRPid, Pid, Socket, Msg, LinkPid) when is_binary(Msg),
									   byte_size(Msg) > 0 ->
	LinkPid ! {Pid, vdrmsgsent},
	VDRPid ! {Pid, Socket, Msg, noresp};
do_send_msg2vdr(_VDRPid, _Pid, _Socket, Msg, _LinkPid) when is_binary(Msg),
									   byte_size(Msg) < 1 ->
	ok;
do_send_msg2vdr(VDRPid, Pid, Socket, Msg, LinkPid) when is_list(Msg),
									   length(Msg) > 0 ->
	[H|T] = Msg,
	LinkPid ! {Pid, vdrmsgsent},
	VDRPid ! {Pid, Socket, H, noresp},
	do_send_msg2vdr(VDRPid, Pid, Socket, T, LinkPid);
do_send_msg2vdr(_VDRPid, _Pid, _Socket, Msg, _LinkPid) when is_list(Msg),
									     length(Msg) < 1 ->
	ok;
do_send_msg2vdr(_VDRPid, _Pid, _Socket, _Msg, _LinkPid) ->
	ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
remove_empty_item_in_binary_list(BinList, Result) when is_list(BinList),
											           length(BinList) > 0 ->
	[H|T] = BinList,
	if
		H == <<"">> ->
			remove_empty_item_in_binary_list(T, Result);
		true ->
			remove_empty_item_in_binary_list(T, lists:append(Result, [H]))
	end;
remove_empty_item_in_binary_list(_BinList, Result) ->
	Result.

get_binary_msg_first_n_char(Msg, N) when is_binary(Msg),
										 is_integer(N),
										 byte_size(Msg) > N ->
	erlang:binary_part(Msg, 0, N);
get_binary_msg_first_n_char(_Msg, _N) ->
	<<"">>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_sql_to_db(PoolId, Msg, State) ->
	LinkPid = State#vdritem.linkpid,
	Pid = State#vdritem.pid,
    case State#vdritem.dbpid of
        undefined ->
			LinkPid ! {Pid, dbmsgerror};
        DBPid ->
			BinOper = get_binary_msg_first_n_char(Msg, 12),
			if
				BinOper == <<"insert into ">> ->
					[TableName, Fields, Values] = remove_empty_item_in_binary_list(binary:split(Msg, [<<"insert into ">>, <<"(">>, <<") values(">>, <<")">>], [global]), []),
					if
						Fields == <<"vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag, distance, oil, record_speed, event_man_acq, ex_speed_type, ex_speed_id, alarm_add_type, alarm_add_id, alarm_add_direct, road_alarm_id, road_alarm_time, road_alarm_result, ex_state, io_state, analog_quantity_ad0, analog_quantity_ad1, wl_signal_amp, gnss_count">> ->
							DBPid ! {Pid, insert, TableName, Fields, Values},
							LinkPid ! {Pid, dbmsgstored, 1},
				            receive
				                {Pid, Result} ->
				                    Result
				            end;
						true ->
				            DBPid ! {State#vdritem.pid, PoolId, Msg},
							LinkPid ! {Pid, dbmsgstored, 1},
				            receive
				                {Pid, Result} ->
				                    Result
				            end
					end;
				true ->
					BinOper1 = get_binary_msg_first_n_char(Msg, 34),
					if
						BinOper1 == <<"replace into vehicle_position_last">> ->
							[TableName1, Fields1, Values1] = remove_empty_item_in_binary_list(binary:split(Msg, [<<"replace into ">>, <<"(">>, <<") values(">>, <<")">>], [global]), []),
							if
								Fields1 == <<"vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag, distance, oil, record_speed, event_man_acq, ex_speed_type, ex_speed_id, alarm_add_type, alarm_add_id, alarm_add_direct, road_alarm_id, road_alarm_time, road_alarm_result, ex_state, io_state, analog_quantity_ad0, analog_quantity_ad1, wl_signal_amp, gnss_count">> ->
									DBPid ! {Pid, replace, TableName1, Fields1, Values1},
									LinkPid ! {Pid, dbmsgstored, 1},
						            receive
						                {Pid, Result} ->
						                    Result
						            end;
								true ->
						            DBPid ! {Pid, PoolId, Msg},
									LinkPid ! {Pid, dbmsgstored, 1},
						            receive
						                {Pid, Result} ->
						                    Result
						            end
							end;
						true ->
				            DBPid ! {Pid, PoolId, Msg},
							LinkPid ! {Pid, dbmsgstored, 1},
				            receive
				                {Pid, Result} ->
				                    Result
				            end
					end
			end
    end.

send_sql_to_db_nowait(PoolId, Msg, State) ->
	LinkPid = State#vdritem.linkpid,
	Pid = State#vdritem.pid,
    case State#vdritem.dbpid of
        undefined ->
			LinkPid ! {Pid, dbmsgerror};
        DBPid ->
			BinOper = get_binary_msg_first_n_char(Msg, 12),
			if
				BinOper == <<"insert into ">> ->
					[TableName, Fields, Values] = remove_empty_item_in_binary_list(binary:split(Msg, [<<"insert into ">>, <<"(">>, <<") values(">>, <<")">>], [global]), []),
					if
						Fields == <<"vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag">> ->
							DBPid ! {Pid, insert, TableName, Fields, Values, noresp};
						true ->
				            DBPid ! {Pid, PoolId, Msg, noresp}
					end;
				true ->
					BinOper1 = get_binary_msg_first_n_char(Msg, 34),
					if
						BinOper1 == <<"replace into vehicle_position_last">> ->
							[TableName1, Fields1, Values1] = remove_empty_item_in_binary_list(binary:split(Msg, [<<"replace into ">>, <<"(">>, <<") values(">>, <<")">>], [global]), []),
							if
								Fields1 == <<"vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag, distance, oil, record_speed, event_man_acq, ex_speed_type, ex_speed_id, alarm_add_type, alarm_add_id, alarm_add_direct, road_alarm_id, road_alarm_time, road_alarm_result, ex_state, io_state, analog_quantity_ad0, analog_quantity_ad1, wl_signal_amp, gnss_count">> ->
									DBPid ! {Pid, replace, TableName1, Fields1, Values1, noresp};
								true ->
						            DBPid ! {Pid, PoolId, Msg, noresp}
							end;
						true ->
				            DBPid ! {Pid, PoolId, Msg}
					end
			end,
			LinkPid ! {Pid, dbmsgstored, 1}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%send_sqls_to_db(PoolId, Msgs, State) when is_list(Msgs),
%										  length(Msgs) > 0 ->
%	[H|T] = Msgs,
%	send_sql_to_db(PoolId, H, State),
%	send_sqls_to_db(PoolId, T, State);
%send_sqls_to_db(_PoolId, _Msgs, _State) ->
%	ok.

send_sqls_to_db_nowait(PoolId, Msgs, State) when is_list(Msgs),
								  		         length(Msgs) > 0 ->
	[H|T] = Msgs,
	send_sql_to_db_nowait(PoolId, H, State),
	send_sqls_to_db_nowait(PoolId, T, State);
send_sqls_to_db_nowait(_PoolId, _Msgs, _State) ->
	ok.

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

send_msg_to_ws_nowait(Msg, State) ->
    case State#vdritem.wspid of
        undefined ->
            ok;
        WSPid ->
            WSPid ! {State#vdritem.pid, Msg, noresp}
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
        16#200 ->
			create_pos_info_sql(Msg, State);
        16#201 ->
			create_pos_info_sql(Msg, State);
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
			MsgSize = tuple_size(Msg),
			if
				MsgSize == 2 ->
					{DrvState, Time} = Msg,
			            <<YY:8, MMon:8, DD:8, HH:8, MMin:8, SS:8>> = <<Time:48>>,
			            Year = common:convert_bcd_integer(YY),
			            Month = common:convert_bcd_integer(MMon),
			            Day = common:convert_bcd_integer(DD),
			            Hour = common:convert_bcd_integer(HH),
			            Minute = common:convert_bcd_integer(MMin),
			            Second = common:convert_bcd_integer(SS),
			            YearS = common:integer_to_binary(Year),
			            MonthS = common:integer_to_binary(Month),
			            DayS = common:integer_to_binary(Day),
			            HourS = common:integer_to_binary(Hour),
			            MinuteS = common:integer_to_binary(Minute),
			            SecondS = common:integer_to_binary(Second),
			            TimeS = list_to_binary([YearS, <<"-">>, MonthS, <<"-">>, DayS, <<" ">>, HourS, <<":">>, MinuteS, <<":">>, SecondS]),
			            SQL = list_to_binary([<<"insert into driver_record(vehicle_id, ontime, type) values(">>,
											  common:integer_to_binary(State#vdritem.vehicleid), <<", '">>,
											  TimeS, <<"', ">>,
											  common:integer_to_binary(DrvState), <<")">>]),
			            {ok, SQL};
				MsgSize == 3 ->
					{DrvState, Time, IcReadResult} = Msg,
			            <<YY:8, MMon:8, DD:8, HH:8, MMin:8, SS:8>> = <<Time:48>>,
			            Year = common:convert_bcd_integer(YY),
			            Month = common:convert_bcd_integer(MMon),
			            Day = common:convert_bcd_integer(DD),
			            Hour = common:convert_bcd_integer(HH),
			            Minute = common:convert_bcd_integer(MMin),
			            Second = common:convert_bcd_integer(SS),
			            YearS = common:integer_to_binary(Year),
			            MonthS = common:integer_to_binary(Month),
			            DayS = common:integer_to_binary(Day),
			            HourS = common:integer_to_binary(Hour),
			            MinuteS = common:integer_to_binary(Minute),
			            SecondS = common:integer_to_binary(Second),
			            TimeS = list_to_binary([YearS, <<"-">>, MonthS, <<"-">>, DayS, <<" ">>, HourS, <<":">>, MinuteS, <<":">>, SecondS]),
			            SQL = list_to_binary([<<"insert into driver_record(vehicle_id, ontime, status, type) values(">>,
											  common:integer_to_binary(State#vdritem.vehicleid), <<", '">>,
											  TimeS, <<"', ">>,
											  common:integer_to_binary(IcReadResult), <<", ">>,
											  common:integer_to_binary(DrvState), <<")">>]),
			            {ok, SQL};
				MsgSize == 9 ->
					{DrvState, Time, IcReadResult, _NameLen, N, C, _OrgLen, O, Validity} = Msg,
		            <<YY:8, MMon:8, DD:8, HH:8, MMin:8, SS:8>> = <<Time:48>>,
		            Year = common:convert_bcd_integer(YY),
		            Month = common:convert_bcd_integer(MMon),
		            Day = common:convert_bcd_integer(DD),
		            Hour = common:convert_bcd_integer(HH),
		            Minute = common:convert_bcd_integer(MMin),
		            Second = common:convert_bcd_integer(SS),
		            YearS = common:integer_to_binary(Year),
		            MonthS = common:integer_to_binary(Month),
		            DayS = common:integer_to_binary(Day),
		            HourS = common:integer_to_binary(Hour),
		            MinuteS = common:integer_to_binary(Minute),
		            SecondS = common:integer_to_binary(Second),
		            TimeS = list_to_binary([YearS, <<"-">>, MonthS, <<"-">>, DayS, <<" ">>, HourS, <<":">>, MinuteS, <<":">>, SecondS]),
		            <<YY1:16, MMon1:8, DD1:8>> = <<Validity:32>>,
		            Year1 = common:convert_bcd_integer(YY1),
		            Month1 = common:convert_bcd_integer(MMon1),
		            Day1 = common:convert_bcd_integer(DD1),
		            Year1S = common:integer_to_binary(Year1),
		            Month1S = common:integer_to_binary(Month1),
		            Day1S = common:integer_to_binary(Day1),
		            ValidityS = list_to_binary([Year1S, <<"-">>, Month1S, <<"-">>, Day1S]),
					ONew = common:convert_gbk_to_utf8(O),
					NNew = common:convert_gbk_to_utf8(N),
					common:loginfo("GBK Org : ~p", [common:get_str_bin_to_bin_list(O)]),
					common:loginfo("UTF8 Org : ~p", [common:get_str_bin_to_bin_list(ONew)]),
					common:loginfo("GBK Name : ~p", [common:get_str_bin_to_bin_list(N)]),
					common:loginfo("UTF8 Name : ~p", [common:get_str_bin_to_bin_list(NNew)]),
		            SQL = list_to_binary([<<"insert into driver_record(vehicle_id, certificate_code, remark, name, effectivedate, ontime, status, type) values(">>,
										  common:integer_to_binary(State#vdritem.vehicleid), <<", '">>,
		                                  list_to_binary(C), <<"', '">>,
		                                  list_to_binary(ONew), <<"', '">>,
		                                  list_to_binary(NNew), <<"', '">>,
		                                  ValidityS, <<"', '">>,
										  TimeS, <<"', ">>,
										  common:integer_to_binary(IcReadResult), <<", ">>,
										  common:integer_to_binary(DrvState), <<")">>]),
		            {ok, SQL}
			end;
        16#704  ->
            {ok, ""};
        16#705  ->
            {ok, ""};
        16#800  ->
            {ok, ""};
        16#801  ->
			{Id, Type, Code, EICode, PipeId, MsgBody, Pack} = Msg,
			VehicleId = State#vdritem.vehicleid,
            {ServerYear, ServerMonth, ServerDay} = erlang:date(),
            {ServerHour, ServerMinute, ServerSecond} = erlang:time(),
            ServerYearS = common:integer_to_binary(ServerYear),
            ServerMonthS = common:integer_to_binary(ServerMonth),
            ServerDayS = common:integer_to_binary(ServerDay),
            ServerHourS = common:integer_to_binary(ServerHour),
            ServerMinuteS = common:integer_to_binary(ServerMinute),
            ServerSecondS = common:integer_to_binary(ServerSecond),
            ServerTimeS = list_to_binary([ServerYearS, <<"-">>, ServerMonthS, <<"-">>, ServerDayS, <<" ">>, ServerHourS, <<":">>, ServerMinuteS, <<":">>, ServerSecondS]),
            ServerTimeSFile = list_to_binary([ServerYearS, <<"_">>, ServerMonthS, <<"_">>, ServerDayS, <<"_">>, ServerHourS, <<"_">>, ServerMinuteS, <<"_">>, ServerSecondS]),
			%file:write_file("media0", Pack),
			%common:loginfo("Pack : ~p~n", [Pack]),
			%Pack1 = binary:replace(Pack, <<39>>, <<255,254,253,252,251,250,251,252,253,254,255,254,253,252,251,250,251,252,253,254,255>>, [global]),
			%common:loginfo("Pack1 : ~p~n", [Pack1]),
			%Pack2 = binary:replace(Pack1, <<255,254,253,252,251,250,251,252,253,254,255,254,253,252,251,250,251,252,253,254,255>>, <<92,39>>, [global]),
			%common:loginfo("Pack2 : ~p~n", [Pack2]),
			%case file:make_dir("media") of
			%	ok ->
			%		common:loginfo("Successfully create directory media~n");
			%	{error, DirError} ->
			%		common:logerror("Cannot create directory media : ~p~n", [DirError])
			%end,
			%case file:get_cwd() of
			%	{ok, Dir} ->
			%		common:loginfo("Current directory ~p~n", [Dir]);
			%	{error, CwdError} ->
			%		common:logerror("Cannot get the current directory : ~p~n", [CwdError])
			%end,
			FileNameDB = common:combine_strings([integer_to_list(State#vdritem.tel), "_",
											     binary_to_list(ServerTimeSFile), "_",
											     integer_to_list(Id), "_",
											     integer_to_list(Type), "_",
											     integer_to_list(Code), "_",
											     integer_to_list(EICode), "_",
											     integer_to_list(PipeId), ".dat"], false),											   										    
			[{path, Path}] = ets:lookup(msgservertable, path),
			FileName = Path ++ common:combine_strings(["/media/",
											   integer_to_list(State#vdritem.tel), "_",
											   binary_to_list(ServerTimeSFile), "_",
											   integer_to_list(Id), "_",
											   integer_to_list(Type), "_",
											   integer_to_list(Code), "_",
											   integer_to_list(EICode), "_",
											   integer_to_list(PipeId), ".dat"], false),											   										    
			case file:write_file(FileName, Pack) of
				ok ->
					common:loginfo("Successfully save media file ~p~n", [FileName]);
				{error, FileError} ->
					common:logerror("Cannot save media file ~p : ~p~n", [FileName, FileError])
			end,
			%file:write_file("media1", Pack2),
            %SQL = list_to_binary([<<"insert into record_media(vehicle_id, rec_time, mediadata, mediatype, mediaformat, mediaid, eventid, mediachannelid, file_name) values(">>,
			%				     common:integer_to_binary(VehicleId), <<", '">>,
            %                     ServerTimeS, <<"', '">>,
            %                     Pack2, <<"', ">>,
            %                     common:integer_to_binary(Type), <<", ">>,
            %                     common:integer_to_binary(Code), <<", ">>,
            %                     common:integer_to_binary(Id), <<", ">>,
            %                     common:integer_to_binary(EICode), <<", ">>,
			%				     common:integer_to_binary(PipeId), <<", '">>,
			%					  list_to_binary(FileNameDB), <<"')">>]),
            SQL = list_to_binary([<<"insert into record_media(vehicle_id, rec_time, mediatype, mediaformat, mediaid, eventid, mediachannelid, file_name) values(">>,
							      common:integer_to_binary(VehicleId), <<", '">>,
                                  ServerTimeS, <<"', ">>,
                                  common:integer_to_binary(Type), <<", ">>,
                                  common:integer_to_binary(Code), <<", ">>,
                                  common:integer_to_binary(Id), <<", ">>,
                                  common:integer_to_binary(EICode), <<", ">>,
							      common:integer_to_binary(PipeId), <<", '">>,
								  list_to_binary(FileNameDB), <<"')">>]),
			{ok, [SQL0, SQL1]} = create_pos_info_sql(MsgBody, State),
            {ok, [SQL, SQL0, SQL1]};
        16#802  ->
            {ok, ""};
        16#805  ->
            {ok, ""};
        16#900 ->
            {ok, ""};
        16#901 ->
            {ok, ""};
        16#A00 ->
            {ok, ""};
        _ ->
            {error, iderror}
    end.

create_pos_info_sql(Msg, State) ->
    case Msg of
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
   			{AIKey, AIVal} = create_pos_app_sql(AppInfo),
            SQL0 = list_to_binary([<<"insert into vehicle_position_">>, DBBin,
                                   <<"(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag">>, 
								   AIKey, <<") values(">>,
                                  common:integer_to_binary(VehicleID), <<", '">>,
                                  TimeS, <<"', '">>,
                                  ServerTimeS, <<"', ">>,
                                  common:float_to_binary(Lon/1000000.0), <<", ">>,
                                  common:float_to_binary(Lat/1000000.0), <<", ">>,
                                  common:integer_to_binary(Height), <<", ">>,
                                  common:float_to_binary(Speed/10.0), <<", ">>,
                                  common:integer_to_binary(Direction), <<", ">>,
                                  common:integer_to_binary(StateFlag), <<", ">>,
                                  common:integer_to_binary(AlarmSym), AIVal, <<")">>]),
            SQL1 = list_to_binary([<<"replace into vehicle_position_last(vehicle_id, gps_time, server_time, longitude, latitude, height, speed, direction, status_flag, alarm_flag">>, 
								   AIKey, <<") values(">>,
                                  common:integer_to_binary(VehicleID), <<", '">>,
                                  TimeS, <<"', '">>,
                                  ServerTimeS, <<"', ">>,
                                  common:float_to_binary(Lon/1000000.0), <<", ">>,
                                  common:float_to_binary(Lat/1000000.0), <<", ">>,
                                  common:integer_to_binary(Height), <<", ">>,
                                  common:float_to_binary(Speed/10.0), <<", ">>,
                                  common:integer_to_binary(Direction), <<", ">>,
                                  common:integer_to_binary(StateFlag), <<", ">>,
                                  common:integer_to_binary(AlarmSym), AIVal, <<")">>]),
            {ok, [SQL0, SQL1]};
		_ ->
			error
    end.

create_pos_app_sql(AppInfo) ->
	Init = [{16#1, <<", distance">>, <<", NULL">>}, 
			{16#2, <<", oil">>, <<", NULL">>}, 
			{16#3, <<", record_speed">>, <<", NULL">>},
			{16#4, <<", event_man_acq">>, <<", NULL">>}, 
			{16#11, <<", ex_speed_type, ex_speed_id">>, <<", NULL, NULL">>},
			{16#12, <<", alarm_add_type, alarm_add_id, alarm_add_direct">>, <<", NULL, NULL, NULL">>}, 
			{16#13, <<", road_alarm_id, road_alarm_time, road_alarm_result">>, <<", NULL, NULL, NULL">>}, 
			{16#25, <<", ex_state">>, <<", NULL">>}, 
			{16#2A, <<", io_state">>, <<", NULL">>}, 
			{16#2B, <<", analog_quantity_ad0, analog_quantity_ad1">>, <<", NULL, NULL">>}, 
			{16#30, <<", wl_signal_amp">>, <<", NULL">>}, 
			{16#31, <<", gnss_count">>, <<", NULL">>}],
	combine_pos_app_sql_parts(create_pos_app_sql_part(Init, AppInfo)).

combine_pos_app_sql_parts(Parts) when is_list(Parts),
							  		  length(Parts) > 0 ->
	[H|T] = Parts,
	{_ID, Key, Val} = H,
	{A, B} = combine_pos_app_sql_parts(T),
	{list_to_binary([Key, A]), list_to_binary([Val, B])};
combine_pos_app_sql_parts(_Parts) ->
	{[], []}.

create_pos_app_sql_part(Init, AppInfo) when is_list(AppInfo),
									        length(AppInfo) > 0 ->
	[H|T] = AppInfo,
	case H of
		[ID, Res] ->
			case ID of
				16#1 ->
					A = <<", distance">>,
					B = list_to_binary([<<", ">>, common:float_to_binary(Res / 10.0)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#1, {A, B}), T);
				16#2 ->
					A = <<", oil">>,
					B = list_to_binary([<<", ">>, common:float_to_binary(Res / 10.0)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#2, {A, B}), T);
				16#3 ->
					A = <<", record_speed">>,
					B = list_to_binary([<<", ">>, common:float_to_binary(Res / 10.0)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#3, {A, B}), T);
				16#4 ->
					A = <<", event_man_acq">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#4, {A, B}), T);
				16#11 ->
					A = <<", ex_speed_type">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#11, {A, B}), T);
				16#25 ->
					A = <<", ex_state">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#25, {A, B}), T);
				16#2A ->
					A = <<", io_state">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#2A, {A, B}), T);
				16#30 ->
					A = <<", wl_signal_amp">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#30, {A, B}), T);
				16#31 ->
					A = <<", gnss_count">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#31, {A, B}), T);
				_ ->
					create_pos_app_sql_part(Init, T)
			end;				
		[ID, Res1, Res2] ->
			case ID of
				16#11 ->
					A = <<", ex_speed_type, ex_speed_id">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res1), <<", ">>, common:integer_to_binary(Res2)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#11, {A, B}), T);
				16#2B ->
					A = <<", analog_quantity_ad0, analog_quantity_ad1">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res1), <<", ">>, common:integer_to_binary(Res2)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#2B, {A, B}), T);
				_ ->
					create_pos_app_sql_part(Init, T)
			end;
		[ID, Res1, Res2, Res3] ->
			case ID of
				16#12 ->
					A = <<", alarm_add_type, alarm_add_id, alarm_add_direct">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res1), <<", ">>, common:integer_to_binary(Res2), <<", ">>, common:integer_to_binary(Res3)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#12, {A, B}), T);
				16#13 ->
					A = <<", road_alarm_id, road_alarm_time, road_alarm_result">>,
					B = list_to_binary([<<", ">>, common:integer_to_binary(Res1), <<", ">>, common:integer_to_binary(Res2), <<", ">>, common:integer_to_binary(Res3)]),
					create_pos_app_sql_part(replace_pos_app_list(Init, 16#13, {A, B}), T);
				_ ->
					create_pos_app_sql_part(Init, T)
			end;
		_ ->
			[<<>>, <<>>]
	end;
create_pos_app_sql_part(Init, _AppInfo) ->
	Init.

replace_pos_app_list(Init, ID, Item) when is_list(Init),
									      length(Init) > 0 ->
	[H|T] = Init,
	{HID, _HKey, _HValue} = H,
	if
		HID == ID ->
			{NewKey, NewValue} = Item,
			lists:append([[{HID, NewKey, NewValue}], T]);
		true ->
			lists:append([[H], replace_pos_app_list(T, ID, Item)])			
	end;
replace_pos_app_list(Init, _ID, _Item) ->
	Init.

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

