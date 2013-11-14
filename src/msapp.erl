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
    Pid = self(),
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
    %ets:insert(msgservertable, {sysinit4ws, true}),
    ets:insert(msgservertable, {apppid, Pid}),
    %ets:insert(msgservertable, {wscount, 0}),
    %ets:insert(msgservertable, {dbcount, 0}),
    ets:insert(msgservertable, {dblog, []}),
    ets:insert(msgservertable, {wslog, []}),
    common:loginfo("StartType : ~p~n", [StartType]),
    common:loginfo("StartArgs : ~p~n", [StartArgs]),
    ets:new(vdrdbtable,[ordered_set,public,named_table,{keypos,#vdritem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(vdrtable,[ordered_set,public,named_table,{keypos,#vdritem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(mantable,[set,public,named_table,{keypos,#manitem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(usertable,[set,public,named_table,{keypos,#user.id},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(montable,[set,public,named_table,{keypos,#monitem.socket},{read_concurrency,true},{write_concurrency,true}]),
    common:loginfo("Tables are initialized.~n"),
	%case file:get_cwd() of
	%	{ok, Dir} ->
	%		common:loginfo("Current directory ~p~n", [Dir]);
	%	{error, CwdError} ->
	%		common:logerror("Cannot get the current directory : ~p~n", [CwdError])
	%end,
	case file:make_dir(Path ++ "/media") of
		ok ->
			common:loginfo("Successfully create directory media~n");
		{error, DirError0} ->
			common:logerror("Cannot create directory media : ~p~n", [DirError0])
	end,
	case file:make_dir(Path ++ "/upgrade") of
		ok ->
			common:loginfo("Successfully create directory upgrade~n");
		{error, DirError1} ->
			common:logerror("Cannot create directory upgrade : ~p~n", [DirError1])
	end,
    case supervisor:start_link(mssup, []) of
        {ok, SupPid} ->
            ets:insert(msgservertable, {suppid, SupPid}),
            common:loginfo("Message server starts~n"),
            common:loginfo("Application PID is ~p~n", [Pid]),
            common:loginfo("Supervisor PID : ~p~n", [SupPid]),
            case receive_db_ws_init_msg(false, false, 0, Mode) of
                ok ->
                    %mysql:utf8connect(regauth, DB, undefined, DBUid, DBPwd, DBName, true),
                    mysql:utf8connect(conn, DB, undefined, DBUid, DBPwd, DBName, true),
                    %mysql:utf8connect(cmd, DB, undefined, DBUid, DBPwd, DBName, true),
					%mysql:utf8connect(conn, DB, undefined, DBUid, DBPwd, DBName, true),
					%mysql:utf8connect(conn, DB, undefined, DBUid, DBPwd, DBName, true),
					%mysql:utf8connect(conn, DB, undefined, DBUid, DBPwd, DBName, true),
                    
                    %mysql:fetch(regauth, <<"set names 'utf8">>),
                    %mysql:fetch(conn, <<"set names 'utf8">>),
                    %mysql:fetch(cmd, <<"set names 'utf8">>),
					
					if
						Mode == 1 ->
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
							VdrRespPid = spawn(fun() -> vdr_resp_process() end),
		                    ets:insert(msgservertable, {dbpid, DBPid}),
		                    ets:insert(msgservertable, {wspid, WSPid}),
		                    ets:insert(msgservertable, {linkpid, LinkPid}),
		                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
		                    ets:insert(msgservertable, {ccpid, CCPid}),
		                    ets:insert(msgservertable, {vdrtablepid, VdrTablePid}),
		                    ets:insert(msgservertable, {vdrresppid, VdrRespPid}),
		                    common:loginfo("WS client process PID is ~p~n", [WSPid]),
		                    common:loginfo("DB client process PID is ~p~n", [DBPid]),
		                    common:loginfo("DB table deamon process PID is ~p~n", [DBTablePid]),
		                    common:loginfo("Code convertor process PID is ~p~n", [CCPid]),
		                    common:loginfo("VDR table proceesor process PID is ~p~n", [VdrTablePid]),
		                    common:loginfo("VDR response process PID is ~p~n", [VdrRespPid]),
		                    
							%Pid = self(),
							
				            DBPid ! {Pid, conn, <<"set names 'utf8'">>},
				            receive
				                {Pid, Result} ->
				                    Result
				            end,							
							
							InitSql = <<"select * from device left join vehicle on vehicle.device_id=device.id left join vehicle_alarm on vehicle.id=vehicle_alarm.vehicle_id">>,
							DBPid ! {Pid, conn, InitSql},
				            receive
				                {Pid, SqlRes} ->
                                    case vdr_handler:extract_db_resp(SqlRes) of
                                        error ->
                                            ok;
                                        {ok, empty} ->
                                            ok;
                                        {ok, ResArray} ->
											common:loginfo("Preloaded vehicle/device/alarm count : ~p", length(ResArray))
									end
				            end,
					
		                    CCPid ! {Pid, create},
		                    receive
		                        created ->
		                            common:loginfo("Code convertor table is created~n"),
		                            {ok, Pid}
		                        after ?TIMEOUT_CC_INIT_PROCESS ->
		                            {error, "ERROR : code convertor table is timeout~n"}
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
							VdrRespPid = spawn(fun() -> vdr_resp_process() end),
		                    ets:insert(msgservertable, {dbpid, DBPid}),
		                    ets:insert(msgservertable, {linkpid, LinkPid}),
		                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
		                    ets:insert(msgservertable, {ccpid, CCPid}),
		                    ets:insert(msgservertable, {vdrtablepid, VdrTablePid}),
		                    ets:insert(msgservertable, {vdrresppid, VdrRespPid}),
		                    common:loginfo("DB client process PID is ~p~n", [DBPid]),
		                    common:loginfo("DB table deamon process PID is ~p~n", [DBTablePid]),
		                    common:loginfo("Code convertor process PID is ~p~n", [CCPid]),
		                    common:loginfo("VDR table insert/delete process PID is ~p~n", [VdrTablePid]),
		                    common:loginfo("VDR response process PID is ~p~n", [VdrRespPid]),
		                    
		                    CCPid ! {self(), create},
		                    receive
		                        created ->
		                            common:loginfo("Code convertor table is created~n"),
		                            {ok, Pid}
		                        after ?TIMEOUT_CC_INIT_PROCESS ->
		                            {error, "ERROR : code convertor table is timeout~n"}
		                    end
					end;
                {error, ErrMsg} ->
                    {error, ErrMsg}
            end;
        ignore ->
            common:logerror("Message server fails to start : ignore~n"),
            ignore;
        {error, Error} ->
            common:logerror("Message server fails to start : ~p~n", [Error]),
            {error, Error}
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
			vdrtable_insert_delete_process()
	end.

vdr_resp_process() ->
	receive
		stop ->
			common:loginfo("VDR response process stops.");
		{Pid, Socket, Msg} ->
			%common:loginfo("Msg from VDR ~p to VDRPid ~p : ~p", [Pid, self(), Msg]),
			try gen_tcp:send(Socket, Msg)
		    catch
		        _:Ex ->
		            common:logerror("Exception when gen_tcps:send ~p : ~p~n", [Msg, Ex])
		    end,
			Pid ! {Pid, ok},
			vdr_resp_process();
		{_Pid, Socket, Msg, noresp} ->
			%common:loginfo("Msg from VDR ~p to VDRPid ~p : ~p", [Pid, self(), Msg]),
			try gen_tcp:send(Socket, Msg)
		    catch
		        _:Ex ->
		            common:logerror("Exception when gen_tcps:send ~p : ~p~n", [Msg, Ex])
		    end,
			vdr_resp_process();
		Unknown ->
			common:loginfo("Msg from VDR to VDRPid unknwon : ~p", [Unknown]),
			vdr_resp_process()
	end.

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
    error_logger:info_msg("Message server stops.~n").

code_convertor_process() ->
    receive
        {Pid, create} ->
            code_convertor:init_code_table(),
            common:loginfo("CC process ~p : code table is initialized~n", [self()]),
            Pid ! created,
            code_convertor_process();
        {Pid, gbktoutf8, Src} ->
            try
                common:loginfo("CC process ~p : source GBK from ~p : ~p~n", [self(), Src]),
                Value = code_convertor:to_utf8(Src),
                common:loginfo("CC process ~p : dest UTF8 : ~p~n", [self(), Value]),
                Pid ! code_convertor:to_utf8(Src)
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting GBK to UTF8 : ~p~n", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        {Pid, gbk2utf8, Src} ->
            try
                common:loginfo("CC process ~p : source GBK from ~p : ~p~n", [self(), Src]),
                Value = code_convertor:to_utf8(Src),
                common:loginfo("CC process ~p : dest UTF8 : ~p~n", [self(), Value]),
                Pid ! code_convertor:to_utf8(Src)
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting GBK to UTF8 : ~p~n", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        {Pid, utf82gbk, Src} ->
            try
                common:loginfo("CC process ~p : source UTF8 from ~p : ~p~n", [self(), Src]),
                Value = code_convertor:to_gbk(Src),
                common:loginfo("CC process ~p : dest GBK : ~p~n", [self(), Value]),
                Pid ! Value
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting UTF8 to GBK : ~p~n", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        {Pid, utf8togbk, Src} ->
            try
                common:loginfo("CC process ~p : source UTF8 from ~p : ~p~n", [self(), Src]),
                Value = code_convertor:to_gbk(Src),
                common:loginfo("CC process ~p : dest GBK : ~p~n", [self(), Value]),
                Pid ! Value
            catch
                _:_ ->
                    common:logerror("CC process ~p : EXCEPTION when converting UTF8 to GBK : ~p~n", [self(), Src]),
                    Pid ! Src
            end,
            code_convertor_process();
        stop ->
            ok;
		{Pid, Msg} ->
			common:loginfo("CC process ~p : unknown message from ~p : ~p~n", [self(), Pid, Msg]),
			Pid ! msg,
			code_convertor_process();
		UnknownMsg ->
			common:loginfo("CC process ~p : unknown message : ~p~n", [self(), UnknownMsg]),
			code_convertor_process()
	%after ?CC_PID_TIMEOUT ->
	%		common:loginfo("CC process ~p : current waiting timeout and start another waiting~n", [self()]),
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
            error_logger:info_msg("Check table gps_database.vehicle_position_~p~n", [binary_to_list(Bin)]),
            DBPid ! {Pid, conn, list_to_binary([<<"CREATE TABLE IF NOT EXISTS gps_database.vehicle_position_">>, 
                         Bin,
                         <<" LIKE vehicle_position">>])},
            receive
                {Pid, Result1} ->
                    Result1
            end,
            error_logger:info_msg("Check table gps_database.vehicle_position_~p~n", [binary_to_list(Bin1)]),
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

