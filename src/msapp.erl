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

%cd ../src
%make
%cd ../ebin
%erl
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
    ets:insert(msgservertable, {apppid, AppPid}),
    %ets:insert(msgservertable, {wscount, 0}),
    %ets:insert(msgservertable, {dbcount, 0}),
    ets:insert(msgservertable, {dblog, []}),
    ets:insert(msgservertable, {wslog, []}),
    common:loginfo("StartType : ~p~n", [StartType]),
    common:loginfo("StartArgs : ~p~n", [StartArgs]),
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
            common:loginfo("Application PID is ~p~n", [AppPid]),
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
		                    WSPid = spawn(fun() -> wsock_client:wsock_client_process(0, 0) end),
		                    DBPid = spawn(fun() -> mysql:mysql_process(0, 0) end),
		                    DBTablePid = spawn(fun() -> db_table_deamon() end),
		                    CCPid = spawn(fun() -> code_convertor_process() end),
		                    ets:insert(msgservertable, {dbpid, DBPid}),
		                    ets:insert(msgservertable, {wspid, WSPid}),
		                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
		                    ets:insert(msgservertable, {ccpid, CCPid}),
		                    common:loginfo("WS client process PID is ~p~n", [WSPid]),
		                    common:loginfo("DB client process PID is ~p~n", [DBPid]),
		                    common:loginfo("DB table deamon process PID is ~p~n", [DBTablePid]),
		                    common:loginfo("Code convertor process PID is ~p~n", [CCPid]),
		                    
		                    CCPid ! {self(), create},
		                    receive
		                        created ->
		                            common:loginfo("Code convertor table is created~n"),
		                            {ok, AppPid}
		                        after ?TIMEOUT_CC_INIT_PROCESS ->
		                            {error, "ERROR : code convertor table is timeout~n"}
		                    end;
						true ->
		                    DBPid = spawn(fun() -> mysql:mysql_process(0, 0) end),
		                    DBTablePid = spawn(fun() -> db_table_deamon() end),
		                    CCPid = spawn(fun() -> code_convertor_process() end),
		                    ets:insert(msgservertable, {dbpid, DBPid}),
		                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
		                    ets:insert(msgservertable, {ccpid, CCPid}),
		                    common:loginfo("DB client process PID is ~p~n", [DBPid]),
		                    common:loginfo("DB table deamon process PID is ~p~n", [DBTablePid]),
		                    common:loginfo("Code convertor process PID is ~p~n", [CCPid]),
		                    
		                    CCPid ! {self(), create},
		                    receive
		                        created ->
		                            common:loginfo("Code convertor table is created~n"),
		                            {ok, AppPid}
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
    [{wspid, WSPid}] = ets:lookup(msgservertable, wspid),
    case WSPid of
        undefined ->
            ok;
        _ ->
            WSPid ! stop
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

