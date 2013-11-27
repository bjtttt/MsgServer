%%%
%%%
%%%

-module(msapp).

-behaviour(application).

-include("header.hrl").

%-export([start_client_vdr/1]).

-export([start/2, stop/1]).

%host: 42.96.146.34
%user: optimus
%passwd: opt123450
%port:3306
%dbname: gps_database

%cd /home/optimus/innovbackend/gateway/src
%make
%cd ../ebin
%erl -P 655350 -Q 655350
%application:start(sasl).
%application:start(msapp).

%%%
%%% rawdisplay  : 0 -> error_logger
%%%               1 -> terminal
%%% display     : 1 -> no log
%%%               1 -> log
%%%
start(StartType, StartArgs) ->
    [PortVDR, PortMon, PortMP, WS, PortWS, DB, DBName, DBUid, DBPwd, MaxR, MaxT, Mode, Path] = StartArgs,
    AppPid = self(),
    ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
    ets:insert(msgservertable, {portvdr, PortVDR}),
    ets:insert(msgservertable, {portmon, PortMon}),
    ets:insert(msgservertable, {portmp, PortMP}),
    ets:insert(msgservertable, {ws, WS}),
    ets:insert(msgservertable, {portws, PortWS}),
    ets:insert(msgservertable, {db, DB}),
    ets:insert(msgservertable, {dbname, DBName}),
    ets:insert(msgservertable, {dbuid, DBUid}),
    ets:insert(msgservertable, {dbpwd, DBPwd}),
    ets:insert(msgservertable, {maxr, MaxR}),
    ets:insert(msgservertable, {maxt, MaxT}),
    ets:insert(msgservertable, {mode, Mode}),
    ets:insert(msgservertable, {path, Path}),
    ets:insert(msgservertable, {dbpid, undefined}),
    ets:insert(msgservertable, {wspid, undefined}),
    ets:insert(msgservertable, {linkpid, undefined}),
	ets:insert(msgservertable, {dboperationpid, undefined}),
	ets:insert(msgservertable, {dbmaintainpid, undefined}),
	if
		Mode == 2 orelse Mode == 1 ->
			ets:insert(msgservertable, {dbstate, true});
		true ->
			ets:insert(msgservertable, {dbstate, false})
	end,
    ets:insert(msgservertable, {apppid, AppPid}),
    ets:insert(msgservertable, {dblog, []}),
    ets:insert(msgservertable, {wslog, []}),
    common:loginfo("StartType : ~p", [StartType]),
    common:loginfo("StartArgs : ~p", [StartArgs]),
    ets:new(alarmtable,[bag,public,named_table,{keypos,#alarmitem.vehicleid},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(vdrdbtable,[ordered_set,public,named_table,{keypos,#vdrdbitem.authencode},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(vdrtable,[ordered_set,public,named_table,{keypos,#vdritem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(mantable,[set,public,named_table,{keypos,#manitem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(usertable,[set,public,named_table,{keypos,#user.id},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(montable,[set,public,named_table,{keypos,#monitem.socket},{read_concurrency,true},{write_concurrency,true}]),
    common:loginfo("Tables are initialized."),
	case file:make_dir(Path ++ "/media") of
		ok ->
			common:loginfo("Successfully create directory media");
		{error, DirError0} ->
			common:logerror("Cannot create directory media : ~p", [DirError0])
	end,
	case file:make_dir(Path ++ "/upgrade") of
		ok ->
			common:loginfo("Successfully create directory upgrade");
		{error, DirError1} ->
			common:logerror("Cannot create directory upgrade : ~p", [DirError1])
	end,
    case supervisor:start_link(mssup, []) of
        {ok, SupPid} ->
            ets:insert(msgservertable, {suppid, SupPid}),
            common:loginfo("Message server starts"),
            common:loginfo("Application PID is ~p", [AppPid]),
            common:loginfo("Supervisor PID : ~p", [SupPid]),
            case receive_db_ws_init_msg(false, false, 0, Mode) of
                ok ->
                    mysql:utf8connect(conn, DB, undefined, DBUid, DBPwd, DBName, true),
					if
						Mode == 2 ->
		                    LinkPid = spawn(fun() -> connection_info_process(0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0,
																			 0) end),
		                    WSPid = spawn(fun() -> wsock_client:wsock_client_process(0, 0) end),
		                    DBPid = spawn(fun() -> mysql:mysql_process(0, 0, [<<"">>, <<"">>, []], 0, [<<"">>, <<"">>, []], 0, LinkPid) end),
		                    DBTablePid = spawn(fun() -> db_table_deamon() end),
		                    CCPid = spawn(fun() -> code_convertor_process() end),
		                    VdrTablePid = spawn(fun() -> vdrtable_insert_delete_process() end),
							DBOperationPid = spawn(fun() -> db_data_operation_process(DBPid) end),
							DBMaintainPid = spawn(fun() -> db_data_maintain_process(DBOperationPid, Mode) end),
		                    ets:insert(msgservertable, {dbpid, DBPid}),
		                    ets:insert(msgservertable, {wspid, WSPid}),
		                    ets:insert(msgservertable, {linkpid, LinkPid}),
		                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
		                    ets:insert(msgservertable, {ccpid, CCPid}),
		                    ets:insert(msgservertable, {vdrtablepid, VdrTablePid}),
							ets:insert(msgservertable, {dboperationpid, DBOperationPid}),
		                    ets:insert(msgservertable, {dbmaintainpid, VdrTablePid}),
		                    common:loginfo("WS client process PID is ~p", [WSPid]),
		                    common:loginfo("DB client process PID is ~p", [DBPid]),
		                    common:loginfo("DB table deamon process PID is ~p", [DBTablePid]),
		                    common:loginfo("Code convertor process PID is ~p", [CCPid]),
		                    common:loginfo("VDR table processor process PID is ~p", [VdrTablePid]),
							common:loginfo("DB operation process PID is ~p", [DBOperationPid]),
							common:loginfo("DB miantain process PID is ~p", [DBMaintainPid]),
		                    
				            common:loginfo("DB coding setting"),
							DBPid ! {AppPid, conn, <<"set names 'utf8'">>},
				            receive
				                {AppPid, _} ->
									common:loginfo("DB coding setting returns\nDB device/vehicle init"),
									DBPid ! {AppPid, conn, <<"select * from device left join vehicle on vehicle.device_id = device.id">>},
						            receive
						                {AppPid, Result} ->
											common:loginfo("DB device/vehicle init returns\nDB alarm init"),
											init_vdrdbtable(Result),
											common:loginfo("DB device/vehicle init success : ~p", [ets:info(vdrdbtable, size)]),
											DBPid ! {AppPid, conn, <<"select * from vehicle_alarm where isnull(clear_time)">>},
								            receive
								                {AppPid, AlarmResult} ->
													common:loginfo("DB alarm init returns"),
													init_alarmtable(AlarmResult),
													common:loginfo("DB alarm init success : ~p", [ets:info(alarmtable, size)]),
								                    CCPid ! {AppPid, create},
								                    receive
								                        created ->
								                            common:loginfo("Code convertor table is created"),
								                            {ok, AppPid}
								                        after ?TIMEOUT_CC_INIT_PROCESS ->
								                            {error, "ERROR : code convertor table is timeout"}
													end
						                    after
												?DB_RESP_TIMEOUT ->
						                            {error, "ERROR : init alarm table is timeout"}
											end
									after
										?DB_RESP_TIMEOUT ->
											{error, "ERROR : init device/vehicle db table is timeout"}
						            end
							after
								?DB_RESP_TIMEOUT ->
									{error, "ERROR : init db coding is timeout"}
							end;
						true ->
		                    LinkPid = spawn(fun() -> connection_info_process(0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0, 
																			 0, 0, 0, 0, 0,
																			 0) end),
		                    DBPid = spawn(fun() -> mysql:mysql_process(0, 0, [<<"">>, <<"">>, []], 0, [<<"">>, <<"">>, []], 0, LinkPid) end),
		                    DBTablePid = spawn(fun() -> db_table_deamon() end),
		                    CCPid = spawn(fun() -> code_convertor_process() end),
		                    VdrTablePid = spawn(fun() -> vdrtable_insert_delete_process() end),
							DBOperationPid = spawn(fun() -> db_data_operation_process(DBPid) end),
							DBMaintainPid = spawn(fun() -> db_data_maintain_process(DBOperationPid, Mode) end),
		                    ets:insert(msgservertable, {dbpid, DBPid}),
		                    ets:insert(msgservertable, {linkpid, LinkPid}),
		                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
		                    ets:insert(msgservertable, {ccpid, CCPid}),
		                    ets:insert(msgservertable, {vdrtablepid, VdrTablePid}),
							ets:insert(msgservertable, {dboperationpid, DBOperationPid}),
							ets:insert(msgservertable, {dbmaintainpid, DBMaintainPid}),
		                    common:loginfo("DB client process PID is ~p", [DBPid]),
		                    common:loginfo("DB table deamon process PID is ~p", [DBTablePid]),
		                    common:loginfo("Code convertor process PID is ~p", [CCPid]),
		                    common:loginfo("VDR table processor process PID is ~p", [VdrTablePid]),
		                    common:loginfo("DB operation process PID is ~p", [DBOperationPid]),
		                    common:loginfo("DB miantain process PID is ~p", [DBMaintainPid]),
		                    
							common:loginfo("DB coding setting"),
				            DBPid ! {AppPid, conn, <<"set names 'utf8'">>},
				            receive
				                {AppPid, _} ->
									common:loginfo("DB coding setting returns\nDB device/vehicle init"),
									DBPid ! {AppPid, conn, <<"select * from device left join vehicle on vehicle.device_id = device.id">>},
						            receive
						                {AppPid, Result} ->
											common:loginfo("DB device/vehicle init returns"),
											init_vdrdbtable(Result),
											common:loginfo("DB device/vehicle init success : ~p\nDB alarm init", [ets:info(vdrdbtable, size)]),
											DBPid ! {AppPid, conn, <<"select * from vehicle_alarm where isnull(clear_time)">>},
								            receive
								                {AppPid, AlarmResult} ->
													common:loginfo("DB alarm init returns"),
													init_alarmtable(AlarmResult),
													common:loginfo("DB alarm init success : ~p", [ets:info(alarmtable, size)]),
								                    CCPid ! {AppPid, create},
								                    receive
								                        created ->
								                            common:loginfo("Code convertor table is created"),
								                            {ok, AppPid}
								                        after ?TIMEOUT_CC_INIT_PROCESS ->
								                            {error, "ERROR : code convertor table is timeout"}
													end
						                    after 
												?DB_RESP_TIMEOUT ->
						                            {error, "ERROR : init alarm table is timeout"}
											end
									after
										?DB_RESP_TIMEOUT ->
											{error, "ERROR : init device/vehicle db table is timeout"}
						            end
							after
								?DB_RESP_TIMEOUT ->
									{error, "ERROR : init db coding is timeout"}
							end
					end;
                {error, ErrMsg} ->
                    {error, ErrMsg}
            end;
        ignore ->
            common:logerror("Message server fails to start : ignore"),
            ignore;
        {error, Error} ->
            common:logerror("Message server fails to start : ~p", [Error]),
            {error, Error}
    end.

init_vdrdbtable(Result) ->
	ets:delete_all_objects(vdrdbtable),
	case vdr_handler:extract_db_resp(Result) of
		error ->
			common:logerror("Message server cannot init vdr db table");
		{ok, empty} ->
		    common:logerror("Message server init empty vdr db table");
		{ok, Records} ->
			try
				do_init_vdrdbtable(Records)
			catch
				_:Msg ->
					common:logerror("Message server fails to init vdr db table : ~p", [Msg])
			end
	end.

do_init_vdrdbtable(Result) when is_list(Result),
								length(Result) > 0 ->
	[H|T] = Result,
	{VDRID, VDRSerialNo, VDRAuthenCode, VehicleCode, VehicleID, DriverID} = vdr_handler:get_record_column_info(H),
	if
		VehicleCode =/= undefined andalso binary_part(VehicleCode, 0, 1) =/= <<"?">> ->
			VDRDBItem = #vdrdbitem{authencode=VDRAuthenCode, 
								   vdrid=VDRID, 
								   vdrserialno=VDRSerialNo,
								   vehiclecode=VehicleCode,
								   vehicleid=VehicleID,
								   driverid=DriverID},
			ets:insert(vdrdbtable, VDRDBItem),
			do_init_vdrdbtable(T);
		true ->
			common:logerror("Failt to insert Device/Vehicle : VDRAuthenCode ~p, VDRID ~p, VDRSerialNo ~p, VehicleCode ~p, VehicleID ~p, DriverID ~p",
							[VDRAuthenCode, VDRID, VDRSerialNo, VehicleCode, VehicleID, DriverID]),
			do_init_vdrdbtable(T)
	end;
do_init_vdrdbtable(_Result) ->
	ok.

init_alarmtable(AlarmResult) ->
	ets:delete_all_objects(alarmtable),
	case vdr_handler:extract_db_resp(AlarmResult) of
		error ->
			common:logerror("Message server cannot init alarm table");
		{ok, empty} ->
		    common:logerror("Message server init empty alarm table");
		{ok, Records} ->
			try
				do_init_alarmtable(Records)
			catch
				_:Msg ->
					common:logerror("Message server fails to init alarm table : ~p", [Msg])
			end
	end.

do_init_alarmtable(AlarmResult) when is_list(AlarmResult),
									 length(AlarmResult) > 0 ->
	[H|T] = AlarmResult,
	{<<"vehicle_alarm">>, <<"vehicle_id">>, VehicleID} = vdr_handler:get_record_field(<<"vehicle_alarm">>, H, <<"vehicle_id">>),
	{<<"vehicle_alarm">>, <<"type_id">>, TypeID} = vdr_handler:get_record_field(<<"vehicle_alarm">>, H, <<"type_id">>),
	{<<"vehicle_alarm">>, <<"alarm_time">>, {datetime, AlarmTime}} = vdr_handler:get_record_field(<<"vehicle_alarm">>, H, <<"alarm_time">>),
	%  AlarmTime is {{YY,MM,DD},{Hh,Mm,Ss}}
	if
		VehicleID =/= undefined andalso TypeID =/= undefined andalso AlarmTime =/= undefined ->
			AlarmItem = #alarmitem{vehicleid=VehicleID, 
								   type=TypeID, 
								   time=AlarmTime},
			ets:insert(alarmtable, AlarmItem),
			do_init_alarmtable(T);
		true ->
			common:logerror("Failt to insert alarm : VehicleID ~p, TypeID ~p, ClearTime ~p",
							[VehicleID, TypeID, AlarmTime]),
			do_init_alarmtable(T)
	end;
do_init_alarmtable(_AlarmResult) ->
	ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This process will update device\vehicle table and alarm table every half an hour
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
db_data_maintain_process(DBOperationPid, Mode) ->
	receive
		stop ->
			common:logerror("DB maintain process receive unknown msg.");
		_ ->
			db_data_maintain_process(DBOperationPid, Mode)
	after 3*60*60*1000 ->
			if
				Mode == 2 orelse Mode == 1 ->
					common:loginfo("DB maintain process is active."),
					Pid = self(),
					DBOperationPid ! {Pid, update, devicevehicle},
					receive
						{Pid, updateok} ->
							ok
					end,
					DBOperationPid ! {Pid, update, alarm},
					receive
						{Pid, updateok} ->
							ok
					end,
					db_data_maintain_process(DBOperationPid, Mode);
				true ->
					common:loginfo("DB maintain process is active without DB operation."),
					db_data_maintain_process(DBOperationPid, Mode)
			end
	end.			

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% This process will operate device\vehicle table and alarm table
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
db_data_operation_process(DBPid) ->
	receive
		stop ->
			common:logerror("DB operation process stops.");
		{Pid, update, devicevehicle} ->
			common:loginfo("DB operation process update device/vehicle."),
			ProcPid = self(),
			DBPid ! {ProcPid, conn, <<"select * from device left join vehicle on vehicle.device_id = device.id">>},
            receive
                {ProcPid, Result} ->
					common:loginfo("DB device/vehicle update returns"),
					init_vdrdbtable(Result),
					common:loginfo("DB device/vehicle update success : ~p", [ets:info(vdrdbtable, size)])
			after ?DB_RESP_TIMEOUT * 3 ->	% 10s * 3 = 30s
				common:logerror("ERROR : update device/vehicle db table is timeout")
            end,
			Pid ! {Pid, updateok},
			db_data_operation_process(DBPid);
		{Pid, update, alarm} ->
			common:loginfo("DB operation process update alarm."),
			ProcPid = self(),
			DBPid ! {ProcPid, conn, <<"select * from vehicle_alarm where isnull(clear_time)">>},
            receive
                {ProcPid, AlarmResult} ->
					common:loginfo("DB alarm init returns"),
					init_alarmtable(AlarmResult),
					common:loginfo("DB alarm init success : ~p", [ets:info(alarmtable, size)])
                after ?DB_RESP_TIMEOUT * 3 ->	% 10s * 3 = 30s
                    common:logerror("ERROR : update alarm table is timeout")
			end,
			Pid ! {Pid, updateok},
			db_data_operation_process(DBPid);
		{Pid, replace, alarm, VehicleID, AlarmList} ->
			ets:delete(alarmtable, VehicleID),
			ets:insert(alarmtable, AlarmList),
			Pid ! {Pid, relpaceok},
			db_data_operation_process(DBPid);
		{Pid, lookup, Table, Key} ->
			Res = ets:lookup(Table, Key),
			Pid ! {Pid, Res},
			db_data_operation_process(DBPid);
		{Pid, insert, Table, Object} ->
			ets:insert(Table, Object),
			Pid ! {Pid, insertok},
			db_data_operation_process(DBPid);
		{_Pid, insert, Table, Object, noresp} ->
			ets:insert(Table, Object),
			db_data_operation_process(DBPid);
		{Pid, delete, Table, Key} ->
			ets:delete(Table, Key),
			Pid ! {Pid, deleteok},
			db_data_operation_process(DBPid);
		{_Pid, delete, Table, Key, noresp} ->
			ets:delete(Table, Key),
			db_data_operation_process(DBPid);
		_ ->
			common:logerror("DB operation process receive unknown msg."),
			db_data_operation_process(DBPid)
	end.

vdrtable_insert_delete_process() ->
	receive
		stop ->
			common:loginfo("VDR table insert/delete process stops.");
		{Pid, insert, Object} ->
			ets:insert(vdrtable, Object),
			Pid ! {Pid, ok},
			vdrtable_insert_delete_process();
		{_Pid, insert, Object, noresp} ->
			ets:insert(vdrtable, Object),
			vdrtable_insert_delete_process();
		{Pid, delete, Key} ->
			ets:delete(vdrtable, Key),
			Pid ! {Pid, ok},
			vdrtable_insert_delete_process();
		{_Pid, delete, Key, noresp} ->
			ets:delete(vdrtable, Key),
			vdrtable_insert_delete_process();
		{Pid, count} ->
			Count = ets:info(vdrtable, size),
			Pid ! {Pid, Count},
			vdrtable_insert_delete_process();
		_ ->
			common:logerror("VDR table insert/delete process receive unknown msg."),
			vdrtable_insert_delete_process()
	end.

%vdr_resp_process() ->
%	receive
%		stop ->
%			common:loginfo("VDR response process stops.");
%		{Pid, Socket, Msg} ->
%			vdr_resp_process(),
%			%common:loginfo("Msg from VDR ~p to VDRPid ~p : ~p", [Pid, self(), Msg]),
%			try gen_tcp:send(Socket, Msg)
%		    catch
%		        _:Ex ->
%		            common:logerror("Exception when gen_tcps:send ~p : ~p", [Msg, Ex])
%		    end,
%			Pid ! {Pid, ok};
%		{_Pid, Socket, Msg, noresp} ->
%			vdr_resp_process(),
%			%common:loginfo("Msg from VDR ~p to VDRPid ~p : ~p", [Pid, self(), Msg]),
%			try gen_tcp:send(Socket, Msg)
%		    catch
%		        _:Ex ->
%		            common:logerror("Exception when gen_tcps:send ~p : ~p", [Msg, Ex])
%		    end;
%		Unknown ->
%			common:loginfo("Msg from VDR to VDRPid unknwon : ~p", [Unknown]),
%			vdr_resp_process()
%	end.

%%%
%%%
%%%
stop(_State) ->
    [{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
    case DBPid of
        undefined ->
            ok;
        _ ->
            DBPid ! stop
    end,
    [{vdrtablepid, VdrTablePid}] = ets:lookup(msgservertable, vdrtablepid),
    case VdrTablePid of
        undefined ->
            ok;
        _ ->
            VdrTablePid ! stop
    end,
    [{dbmaintainpid, DBMaintainPid}] = ets:lookup(msgservertable, dbmaintainpid),
    case DBMaintainPid of
        undefined ->
            ok;
        _ ->
            DBMaintainPid ! stop
    end,
    [{dboperationpid, DBOperationPid}] = ets:lookup(msgservertable, dboperationpid),
    case DBOperationPid of
        undefined ->
            ok;
        _ ->
            DBOperationPid ! stop
    end,
    [{vdrresppid, VdrRespPid}] = ets:lookup(msgservertable, vdrresppid),
    case VdrRespPid of
        undefined ->
            ok;
        _ ->
            VdrRespPid ! stop
    end,
    [{wspid, WSPid}] = ets:lookup(msgservertable, wspid),
    case WSPid of
        undefined ->
            ok;
        _ ->
            WSPid ! stop
    end,
    [{linkpid, LinkPid}] = ets:lookup(msgservertable, linkpid),
    case LinkPid of
        undefined ->
            ok;
        _ ->
            LinkPid ! stop
    end,
    [{dbtablepid, DBTablePid}] = ets:lookup(msgservertable, dbtablepid),
    case DBTablePid of
        undefined ->
            ok;
        _ ->
            DBTablePid ! stop
    end,
    [{ccpid, CCPid}] = ets:lookup(msgservertable, ccpid),
    case CCPid of
        undefined ->
            ok;
        _ ->
            CCPid ! stop
    end,
    error_logger:info_msg("Message server stops.").

code_convertor_process() ->
    receive
        {Pid, create} ->
            code_convertor:init_code_table(),
            common:loginfo("CC process ~p : code table is initialized", [self()]),
            Pid ! created,
            code_convertor_process();
        {Pid, gbktoutf8, Src} ->
            try
                common:loginfo("CC process ~p : source GBK from ~p : ~p", [self(), Src]),
                Value = code_convertor:to_utf8(Src),
                common:loginfo("CC process ~p : dest UTF8 : ~p", [self(), Value]),
                Pid ! code_convertor:to_utf8(Src)
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting GBK to UTF8 : ~p", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        {Pid, gbk2utf8, Src} ->
            try
                common:loginfo("CC process ~p : source GBK from ~p : ~p", [self(), Src]),
                Value = code_convertor:to_utf8(Src),
                common:loginfo("CC process ~p : dest UTF8 : ~p", [self(), Value]),
                Pid ! code_convertor:to_utf8(Src)
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting GBK to UTF8 : ~p", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        {Pid, utf82gbk, Src} ->
            try
                common:loginfo("CC process ~p : source UTF8 from ~p : ~p", [self(), Src]),
                Value = code_convertor:to_gbk(Src),
                common:loginfo("CC process ~p : dest GBK : ~p", [self(), Value]),
                Pid ! Value
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting UTF8 to GBK : ~p", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        {Pid, utf8togbk, Src} ->
            try
                common:loginfo("CC process ~p : source UTF8 from ~p : ~p", [self(), Src]),
                Value = code_convertor:to_gbk(Src),
                common:loginfo("CC process ~p : dest GBK : ~p", [self(), Value]),
                Pid ! Value
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting UTF8 to GBK : ~p", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        stop ->
            ok;
		{Pid, Msg} ->
			common:loginfo("CC process ~p : unknown message from ~p : ~p", [self(), Pid, Msg]),
			Pid ! msg,
			code_convertor_process();
		UnknownMsg ->
			common:loginfo("CC process ~p : unknown message : ~p", [self(), UnknownMsg]),
			code_convertor_process()
	%after ?CC_PID_TIMEOUT ->
	%		common:loginfo("CC process ~p : current waiting timeout and start another waiting", [self()]),
	%		code_convertor_process()
    end.
            
connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
						LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
						UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
						ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
						VDRMsgGot, VDRMsgSent) ->
	receive
		stop ->
			ok;
		{_Pid, test} ->
			connection_info_process(Conn+1, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, conn} ->
			connection_info_process(Conn+1, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, chardisc} ->
			connection_info_process(Conn, CharDisc+1, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, regdisc} ->
			connection_info_process(Conn, CharDisc, RegDisc+1, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, authdisc} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc+1, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, errdisc} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc+1, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, clientdisc} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc+1, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, lenerr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr+1, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, parerr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr+1, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, spliterr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr+1, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, resterr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr+1, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, packerr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr+1, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, vdrtimeout} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr+1,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, unauthdisc} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc+1, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, exitdisc} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc+1, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, vdrerr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr+1, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, unvdrerr} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr+1, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, msgex} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx+1, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, gwstop} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop+1,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, servermsg} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg+1, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, invalidmsgerror} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg+1, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, dbmsgstored, N} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored+N, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, dbmsgsent, N} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent+N, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, dbmsgunknown} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown+1, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, dbmsgerror} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError+1, 
									VDRMsgGot, VDRMsgSent);
		{_Pid, vdrmsggot} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot+1, VDRMsgSent);
		{_Pid, vdrmsgsent} ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent+1);
		{_Pid, clear} ->
			connection_info_process(0, 0, 0, 0, 0, 
									0, 0, 0, 0, 0, 
									0, 0, 0, 0, 0, 
									0, 0, 0, 0, 0, 
									0, 0, 0, 0, 0,
									0);
		{Pid, count} ->
			Pid ! {Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
				   LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
				   UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
				   ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
				   VDRMsgGot, VDRMsgSent},
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent);
		_ ->
			connection_info_process(Conn, CharDisc, RegDisc, AuthDisc, ErrDisc, ClientDisc, 
									LenErr, ParErr, SplitErr, RestErr, PackErr, TimeoutErr,
									UnauthDisc, ExitDisc, VdrErr, UnvdrErr, MsgEx, GWStop,
									ServerMsg, InvalidMsg, DBMsgStored, DBMsgSent, DBMsgUnknown, DBMsgError, 
									VDRMsgGot, VDRMsgSent)
	end.

%%%
%%% Will wait 20s
%%%
receive_db_ws_init_msg(WSOK, DBOK, Count, Mode) ->
    if
        Count >= 20 ->
			if
				Mode == 1 ->
		            if
		                WSOK == false andalso DBOK == false ->
		                    {error, "DB and WS both are not ready"};
		                WSOK == true andalso DBOK == false ->
		                    {error, "DB is not ready"};
		                WSOK == false andalso DBOK == true ->
		                    {error, "WS is not ready"};
		                WSOK == true andalso DBOK == true ->
		                    ok;
		                true ->
		                    {error, "Unknown DB and WS states"}
		            end;
				true ->
		            if
		                DBOK == true ->
		                    ok;
		                DBOK == false ->
		                    {error, "DB is not ready"};
		                true ->
		                    {error, "Unknown DB and WS states"}
		            end
			end;
        true ->
			if
				Mode == 1 ->
					if
		                WSOK == true andalso DBOK == true ->
		                    ok;
						true ->
				            receive
				                {_DBPid, dbok} ->
				                    if
				                        WSOK == true ->
				                            ok;
				                        true ->
				                            receive_db_ws_init_msg(WSOK, true, Count+1, Mode)
				                    end;
				                {_WSPid, wsok} ->
				                    if
				                        DBOK == true ->
				                            ok;
				                        true ->
				                            receive_db_ws_init_msg(true, DBOK, Count+1, Mode)
				                    end;
				                _ ->
				                    receive_db_ws_init_msg(WSOK, DBOK, Count+1, Mode)
				            after ?WAIT_LOOP_INTERVAL ->
				                    receive_db_ws_init_msg(WSOK, DBOK, Count+1, Mode)
				            end
					end;
				true ->
					if
		                DBOK == true ->
		                    ok;
						true ->
				            receive
				                {_DBPid, dbok} ->
				                    if
				                        WSOK == true ->
				                            ok;
				                        true ->
				                            receive_db_ws_init_msg(WSOK, true, Count+1, Mode)
				                    end;
				                _ ->
				                    receive_db_ws_init_msg(WSOK, DBOK, Count+1, Mode)
				            after ?WAIT_LOOP_INTERVAL ->
				                    receive_db_ws_init_msg(WSOK, DBOK, Count+1, Mode)
				            end
					end
			end
    end.                

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
db_table_deamon() ->
    Today = erlang:localtime(),%today(),
    Tomorrow = add(Today, 1),
    {{Year, Month, Day}, _} = Today,
    {{Year1, Month1, Day1}, _} = Tomorrow,
    YearS = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Year)),
    MonthS = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Month)),
    DayS = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Day)),
    Year1S = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Year1)),
    Month1S = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Month1)),
    Day1S = vdr_data_processor:get_2_number_integer_from_oct_string(integer_to_list(Day1)),
    Bin = list_to_binary([common:integer_to_2byte_binary(YearS),
              common:integer_to_2byte_binary(MonthS),
              common:integer_to_2byte_binary(DayS)]),
    Bin1 = list_to_binary([common:integer_to_2byte_binary(Year1S),
               common:integer_to_2byte_binary(Month1S),
               common:integer_to_2byte_binary(Day1S)]),
    [{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
    case DBPid of
        undefined ->
            ok;
        _ ->
            Pid = self(),
            error_logger:info_msg("Check table gps_database.vehicle_position_~p", [binary_to_list(Bin)]),
            DBPid ! {Pid, conn, list_to_binary([<<"CREATE TABLE IF NOT EXISTS gps_database.vehicle_position_">>, 
                         Bin,
                         <<" LIKE vehicle_position">>])},
            receive
                {Pid, Result1} ->
                    Result1
            end,
            error_logger:info_msg("Check table gps_database.vehicle_position_~p", [binary_to_list(Bin1)]),
            DBPid ! {Pid, conn, list_to_binary([<<"CREATE TABLE IF NOT EXISTS gps_database.vehicle_position_">>, 
                         Bin1,
                         <<" LIKE vehicle_position">>])},
            receive
                {Pid, Result2} ->
                    Result2
            end
    end,
	receive
		stop ->
			ok;
		_ ->
			db_table_deamon()
	after 23*60*60*1000 ->
			db_table_deamon()
	end.			

%today() -> erlang:localtime().
%tomorrow() -> add(today(), 1).

add(Date, second) ->
    add(Date, 1, seconds);
add(Date, minute) ->
    add(Date, 1, minutes);
add(Date, hour) ->
    add(Date, 1, hours);
add(Date, day) ->
    add(Date, 1);
add(Date, week) ->
    add(Date, 1, weeks);
add(Date, month) ->
    add(Date, 1, months);
add(Date, year) ->
    add(Date, 1, years);
add(Date, N)  ->
    add(Date, N, days).

add(DateTime, N, seconds) ->
    T1 = calendar:datetime_to_gregorian_seconds(DateTime),
    T2 = T1 + N,
    calendar:gregorian_seconds_to_datetime(T2);
add(DateTime, N, minutes) ->
    add(DateTime, 60*N, seconds);
add(DateTime, N, hours) ->
    add(DateTime, 60*N, minutes);
add(DateTime, N, days) ->
    add(DateTime, 24*N, hours);
add(DateTime, N, weeks) ->
    add(DateTime, 7*N, days);
% Adding months is a bit tricky.
add({{YYYY, MM, DD}=Date, Time}, 0, months) ->
    case calendar:valid_date(Date) of
	true  -> {Date, Time};
	false -> add({{YYYY, MM, DD-1}, Time}, 0, months) % Oops, too many days in this month,
                                                          % Remove a day and try again.
    end;
add({{YYYY, MM, DD}, Time}, N, months) when N > 0 andalso MM < 12 ->
    add({{YYYY, MM+1, DD}, Time}, N-1, months);
add({{YYYY, MM, DD}, Time}, N, months) when N > 0 andalso MM =:= 12 ->
    add({{YYYY+1, 1, DD}, Time}, N-1, months); 
add({{YYYY, MM, DD}, Time}, N, months) when N < 0 andalso MM > 1 ->
    add({{YYYY, MM-1, DD}, Time}, N+1, months);
add({{YYYY, MM, DD}, Time}, N, months) when N < 0 andalso MM =:= 1 ->
    add({{YYYY-1, 12, DD}, Time}, N+1, months);
add(Date, N, years) ->
    add(Date, 12*N, months).
     
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%% File END.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

