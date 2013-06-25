%%%
%%%
%%%

-module(msapp).

-behaviour(application).

-include("header.hrl").

%-export([start_client_vdr/1]).

-export([start/2, stop/1]).

%%% start/1 is useless and will be removed in the future
-export([start/1]).

%host: 42.96.146.34
%user: optimus
%passwd: opt123450
%port:3306
%dbname: gps_database

%%%
%%% rawdisplay  : 0 -> error_logger
%%%               1 -> terminal
%%% display     : 1 -> no log
%%%               1 -> log
%%%
start(StartType, StartArgs) ->
    [PortVDR, PortMon, PortMP, WS, PortWS, DB, DBName, DBUid, DBPwd, RawDisplay, Display] = StartArgs,
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
    ets:insert(msgservertable, {dbpid, undefined}),
    ets:insert(msgservertable, {wspid, undefined}),
    ets:insert(msgservertable, {apppid, AppPid}),
    ets:insert(msgservertable, {rawdisplay, RawDisplay}),
    ets:insert(msgservertable, {display, Display}),
    error_logger:info_msg("StartType : ~p~n", [StartType]),
    error_logger:info_msg("StartArgs : ~p~n", [StartArgs]),
    ets:new(vdrtable,[set,public,named_table,{keypos,#vdritem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(vdridsocktable,[set,public,named_table,{keypos,#vdridsockitem.id},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(mantable,[set,public,named_table,{keypos,#manitem.socket},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(usertable,[set,public,named_table,{keypos,#user.id},{read_concurrency,true},{write_concurrency,true}]),
    ets:new(montable,[set,public,named_table,{keypos,#monitem.socket},{read_concurrency,true},{write_concurrency,true}]),
    error_logger:info_msg("Tables are initialized.~n"),
    case supervisor:start_link(mssup, []) of
        {ok, SupPid} ->
            ets:insert(msgservertable, {suppid, SupPid}),
            error_logger:info_msg("Message server starts~n"),
            error_logger:info_msg("Application PID is ~p~n", [AppPid]),
            error_logger:info_msg("Supervisor PID : ~p~n", [SupPid]),
            case receive_db_ws_init_msg(false, false, 0) of
                ok ->
                    mysql:utf8connect(regauth, DB, undefined, DBUid, DBPwd, DBName, true),
                    mysql:utf8connect(conn, DB, undefined, DBUid, DBPwd, DBName, true),
                    mysql:utf8connect(cmd, DB, undefined, DBUid, DBPwd, DBName, true),

                    WSPid = spawn(fun() -> wsock_client:wsock_client_process() end),
                    DBPid = spawn(fun() -> mysql:mysql_process() end),
                    DBTablePid = spawn(fun() -> db_table_deamon() end),
                    ets:insert(msgservertable, {dbpid, DBPid}),
                    ets:insert(msgservertable, {wspid, WSPid}),
                    ets:insert(msgservertable, {dbtablepid, DBTablePid}),
                    error_logger:info_msg("WS client process PID is ~p~n", [WSPid]),
                    error_logger:info_msg("DB client process PID is ~p~n", [DBPid]),
                    error_logger:info_msg("DB table deamon process PID is ~p~n", [DBTablePid]),
					
					mysql:fetch(conn, <<"set names 'utf8">>),
					mysql:fetch(regauth, <<"set names 'utf8">>),
					mysql:fetch(cmd, <<"set names 'utf8">>),

                    {ok, AppPid};
                {error, ErrMsg} ->
                    {error, ErrMsg}
            end;
        ignore ->
            error_logger:error_msg("Message server fails to start : ignore~n"),
            ignore;
        {error, Error} ->
            error_logger:error_msg("Message server fails to start : ~p~n", [Error]),
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
    error_logger:info_msg("Message server stops.~n").

%%%
%%% Will wait 20s
%%%
receive_db_ws_init_msg(WSOK, DBOK, Count) ->
    if
        Count >= 20 ->
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
            receive
                {_DBPid, dbok} ->
                    if
                        WSOK == true ->
                            ok;
                        true ->
                            receive_db_ws_init_msg(WSOK, true, Count+1)
                    end;
                {_WSPid, wsok} ->
                    if
                        DBOK == true ->
                            ok;
                        true ->
                            receive_db_ws_init_msg(true, DBOK, Count+1)
                    end;
                _ ->
                    receive_db_ws_init_msg(WSOK, DBOK, Count+1)
            after ?WAIT_LOOP_INTERVAL ->
                    receive_db_ws_init_msg(WSOK, DBOK, Count+1)
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

%%%
%%% Useless function
%%%
%%%
%%% Steps :
%%%     1. Start connection to DB
%%%     2. Start server for management
%%%     3. Start server for VDR
%%%     4. Start server for monitor
%%%
%%%  msgservertable : common states
%%%  vdrinittable, vdrtable : when VDR connects, keep its socket as key in vdrinittable first.
%%%                           after receiving VDR ID, the entry will be moved to vdrtable and use VDR ID as key instead.
%%%  mantable : 
%%%
start(StartArgs) ->
    PidApp = self(),
	% shall we call add_handler?
	%ti_event_api:start_link(),
	try
		[DefPort, DefPortMan, DefDB, DefPortDB, DefPortMon] = StartArgs,
		ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(vdrinittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(vdrtable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(mantable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		error_logger:info_msg("Server tables are ok.~n"),
		% make sure that msgserver can get stop message from any internal process?
	    ets:insert(msgservertable, {apppid,PidApp}),
		error_logger:info_msg("Server application PID : ~p~n",[PidApp]),
		% start DB client
		case gen_tcp:listen(DefPortDB, [{active,true}]) of
			{ok, LSock} ->
				error_logger:info_msg("Database starts listening.~n"),
				case ti_sup_db:start_link(LSock, DefDB, DefPortDB) of
			        {ok, Pid} ->
						error_logger:info_msg("Database supervisor starts.~n"),
			            ets:insert(msgservertable, {supdbpid, Pid}),
			            ets:insert(msgservertable, {supdblsock, LSock}),
			            ti_sup_db:start_child(),
						% start management server, VDR server & monitor server
						case start_server_man(DefPortMan, DefPort, DefPortMon) of
							ok ->
								error_logger:info_msg("Msg server starts.~n"),
								{ok, Pid};
							ignore ->
								{error, ignore};
							{error, Error} ->
								{error, Error}
						end;
					ignore ->
                        error_logger:error_msg("Cannot start connetion to DB : ignore~nExit.~n"),
			            {error, ignore};
			        {error, Error} ->
						case Error of
							{already_started, Pid} ->
			            		error_logger:error_msg("Cannot start connetion to DB : already started - ~p~nExit.~n", [Pid]),
                                {error, {already_started, Pid}};
							{shutdown, Term} ->
			            		error_logger:error_msg("Cannot start connetion to DB : shutdown - ~p~nExit.~n", [Term]),
                                {error, {shutdown, Term}};
							Term ->
								error_logger:error_msg("Cannot start connetion to DB : ~p~nExit.~n", [Term]),
                                {error, Term}
						end
			    end;
			{error, Reason} ->
				error_logger:error_msg("Cannot start connetion to DB : ~p~nExit.~n", [Reason]),
                {error, Reason}
		end
	catch
		error:AppError ->
			error_logger:error_msg("Server application fails (error) : ~p~nExit.~n", [AppError]),
            {error, AppError};
		throw:AppThrow ->
			error_logger:error_msg("Server application fails (throw) : ~p~nExit.~n", [AppThrow]),
            {error, AppThrow};
		exit:AppReason ->
			error_logger:error_msg("Server application fails (exit) : ~p~nExit.~n", [AppReason]),
            {error, AppReason}
	end.			

%%%
%%% Useless function
%%%
%%%
%%% Start management server
%%% VDR server and monitor server will also be started here
%%%
start_server_man(PortMan, Port, PortMon) ->
	case gen_tcp:listen(PortMan, [{active, true}]) of
		{ok, LSock} ->
			error_logger:info_msg("Management starts listening.~n"),
		    case ti_sup_man:start_link(LSock) of
		        {ok,Pid} ->
					error_logger:info_msg("Management supervisor starts.~n"),
    				ets:insert(msgservertable,{supmanpid,Pid}),
    				ets:insert(msgservertable,{supmanlsock,LSock}),
		            ti_sup_man:start_child(),
					% start VDR server & monitor server
					start_server(Port, PortMon);
				ignore ->
		            error_logger:error_msg("Cannot start server for management : ignore~nExit.~n"),
                    ignore;
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		error_logger:error_msg("Cannot start server for management : already started - ~p~nExit.~n", [Pid]),
                            {error, shutdown};
						{shutdown, Term} ->
		            		error_logger:error_msg("Cannot start server for management : shutdown - ~p~nExit.~n", [Term]),
                            {error, shutdown};
						Term ->
							error_logger:error_msg("Cannot start server for management : ~p~nExit.~n", [Term]),
                            {error, shutdown}
					end
		    end;
		{error, Reason} ->
			error_logger:error_msg("Cannot start server for management : ~p~nExit.~n", [Reason]),
            {error, shutdown}
	end.

%%%
%%% Useless function
%%%
%%%
%%% Start VDR server
%%% Monitor server will also be started here
%%%
start_server(Port, PortMon) ->
	case gen_tcp:listen(Port, [{active, true}]) of
		{ok, LSock} ->
			error_logger:info_msg("VDR starts listening.~n"),
		    case mssup:start_link(LSock) of
		        {ok, Pid} ->
					error_logger:info_msg("VDR supervisor starts.~n"),
					ets:insert(msgservertable,{suppid,Pid}),
					ets:insert(msgservertable,{suplsock,LSock}),
		            mssup:start_child(),
					% start monitor server
					start_server_mon(PortMon);
				ignore ->
		            error_logger:error_msg("Cannot start server for VDR : ignore~nExit.~n"),
                    ignore;
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		error_logger:error_msg("Cannot start server for VDR : already started - ~p~nExit.~n", [Pid]),
                            {error, {already_started, Pid}};
						{shutdown, Term} ->
		            		error_logger:error_msg("Cannot start server for VDR : shutdown - ~p~nExit.~n", [Term]),
                            {error, {shutdown, Term}};
						Term ->
							error_logger:error_msg("Cannot start server for VDR : ~p~nExit.~n", [Term]),
                            {error, Term}
					end
		    end;
		{error, Reason} ->
			error_logger:error_msg("Cannot start server for VDR : ~p~nExit.~n", [Reason]),
            {error, Reason}
	end.

%%%
%%% Useless function
%%%
%%%
%%% Start monitor server
%%%
start_server_mon(Port) ->
	case gen_tcp:listen(Port, [{active, true}]) of
		{ok, LSock} ->
			error_logger:info_msg("Monitor starts listening.~n"),
		    case ti_sup_mon:start_link(LSock) of
		        {ok, Pid} ->
					error_logger:info_msg("Monitor supervisor starts.~n"),
					ets:insert(msgservertable,{supmonpid,Pid}),
					ets:insert(msgservertable,{supmonlsock,LSock}),
		            ti_sup_mon:start_child(),
				    ok;
				ignore ->
		            error_logger:error_msg("Cannot start server for monitor : ignore~nExit.~n"),
                    ignore;
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		error_logger:error_msg("Cannot start server for monitor : already started - ~p~nExit.~n", [Pid]),
                            {error, {already_started, Pid}};
						{shutdown, Term} ->
		            		error_logger:error_msg("Cannot start server for monitor : shutdown - ~p~nExit.~n", [Term]),
                            {error, {shutdown, Term}};
						Term ->
							error_logger:error_msg("Cannot start server for monitor : ~p~nExit.~n", [Term]),
                            {error, Term}
					end
		    end;
		{error, Reason} ->
			error_logger:error_msg("Cannot start server for monitor : ~p~nExit.~n", [Reason]),
            {error, Reason}
	end.

%%%
%%% Application get stop message.
%%% Need keeping some states?
%%% Is this function proper?
%%%
%app_message_processor() ->
%	receive
%			exit("~p~nMsgServer stops.~n", [Msg]);
%		_ ->
%			app_message_processor()
%	end.




