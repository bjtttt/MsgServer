-module(ti_app).

-behaviour(application).

-include("ti_common.hrl").

-export([start/0, start/2, stop/1]).

start() ->
	start(normal, [?DEF_PORT, ?DEF_PORT_MAN, ?DEF_DB, ?DEF_PORT_DB, ?DEF_PORT_MON]).

%%
%% Steps :
%%     1. Start connection to DB
%%     2. Start server for management
%%     3. Start server for VDR
%%     4. Start server for monitor
%%
%%  msgservertable : common states
%%  vdrinittable, vdrtable : when VDR connects, keep its socket as key in vdrinittable first.
%%                           after receiving VDR ID, the entry will be moved to vdrtable and use VDR ID as key instead.
%%  mantable : 
%%
start(_StartType, StartArgs) ->
	try
		[DefPort, DefPortMan, DefDB, DefPortDB, DefPortMon] = StartArgs,
		ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(vdrinittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(vdrtable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(mantable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		error_logger:error_msg("Server tables are ok.~n"),
		% make sure that msgserver can get stop message from any internal process?
	    PidApp = self(),
	    ets:insert(msgservertable, {apppid,PidApp}),
		error_logger:error_msg("Server application PID : ~p~n",[PidApp]),
		PidAppMsg = spawn(fun() -> app_message_processor() end),
	    ets:insert(msgservertable,{appmsgpid, PidAppMsg}),
	 	error_logger:error_msg("Server application message PID : ~p~n",[PidAppMsg]),
		% start DB client
		case gen_tcp:listen(DefPortDB, [{active,true}]) of
			{ok, LSock} ->
				error_logger:error_msg("Database starts listening.~n"),
				case ti_sup_db:start_link(LSock, DefDB, DefPortDB) of
			        {ok, Pid} ->
						error_logger:error_msg("Database supervisor starts.~n"),
			            ets:insert(msgservertable, {supdbpid, Pid}),
			            ets:insert(msgservertable, {supdblsock, LSock}),
			            ti_sup_db:start_child(),
						% start management server, VDR server & monitor server
						start_server_man(DefPortMan, DefPort, DefPortMon),
						error_logger:error_msg("Msg server starts.~n");
					ignore ->
			            exit("Cannot start connetion to DB : ignore~nExit.~n");
			        {error, Error} ->
						case Error of
							{already_started, Pid} ->
			            		exit("Cannot start connetion to DB : already started - ~p~nExit.~n", [Pid]);
							{shutdown, Term} ->
			            		exit("Cannot start connetion to DB : shutdown - ~p~nExit.~n", [Term]);
							Term ->
								exit("Cannot start connetion to DB : ~p~nExit.~n", [Term])
						end
			    end;
			{error, Reason} ->
				exit("Cannot start connetion to DB : ~p~nExit.~n", [Reason])
		end
	catch
		error:AppError ->
			exit("Server application fails (error) : ~p~nExit.~n", AppError);
		throw:AppThrow ->
			exit("Server application fails (throw) : ~p~nExit.~n", AppThrow);
		exit:AppReason ->
			exit("Server application fails (exit) : ~p~nExit.~n", AppReason)
	end.			

%%%
%%% Start management server
%%% VDR server and monitor server will also be started here
%%%
start_server_man(PortMan, Port, PortMon) ->
	case gen_tcp:listen(PortMan, [{active, true}]) of
		{ok, LSock} ->
			error_logger:error_msg("Management starts listening.~n"),
		    case ti_sup_man:start_link(LSock) of
		        {ok,Pid} ->
					error_logger:error_msg("Management supervisor starts.~n"),
    				ets:insert(msgservertable,{supmanpid,Pid}),
    				ets:insert(msgservertable,{supmanlsock,LSock}),
		            ti_sup_man:start_child(),
					% start VDR server & monitor server
					start_server(Port, PortMon);
				ignore ->
		            exit("Cannot start server for management : ignore~nExit.~n");
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		exit("Cannot start server for management : already started - ~p~nExit.~n", [Pid]);
						{shutdown, Term} ->
		            		exit("Cannot start server for management : shutdown - ~p~nExit.~n", [Term]);
						Term ->
							exit("Cannot start server for management : ~p~nExit.~n", [Term])
					end
		    end;
		{error, Reason} ->
			exit("Cannot start server for management : ~p~nExit.~n", [Reason])
	end.

%%%
%%% Start VDR server
%%% Monitor server will also be started here
%%%
start_server(Port, PortMon) ->
	case gen_tcp:listen(Port, [{active, true}]) of
		{ok, LSock} ->
			error_logger:error_msg("VDR starts listening.~n"),
		    case ti_sup:start_link(LSock) of
		        {ok, Pid} ->
					error_logger:error_msg("VDR supervisor starts.~n"),
					ets:insert(msgservertable,{suppid,Pid}),
					ets:insert(msgservertable,{suplsock,LSock}),
		            ti_sup:start_child(),
					% start monitor server
					start_server_mon(PortMon);
				ignore ->
		            exit("Cannot start server for VDR : ignore~nExit.~n");
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		exit("Cannot start server for VDR : already started - ~p~nExit.~n", [Pid]);
						{shutdown, Term} ->
		            		exit("Cannot start server for VDR : shutdown - ~p~nExit.~n", [Term]);
						Term ->
							exit("Cannot start server for VDR : ~p~nExit.~n", [Term])
					end
		    end;
		{error, Reason} ->
			exit("Cannot start server for VDR : ~p~nExit.~n", [Reason])
	end.

%%%
%%% Start monitor server
%%%
start_server_mon(Port) ->
	case gen_tcp:listen(Port, [{active, true}]) of
		{ok, LSock} ->
			error_logger:error_msg("Monitor starts listening.~n"),
		    case ti_sup_mon:start_link(LSock) of
		        {ok, Pid} ->
					error_logger:error_msg("Monitor supervisor starts.~n"),
					ets:insert(msgservertable,{supmonpid,Pid}),
					ets:insert(msgservertable,{supmonlsock,LSock}),
		            ti_sup_mon:start_child();
				ignore ->
		            exit("Cannot start server for monitor : ignore~nExit.~n");
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		exit("Cannot start server for monitor : already started - ~p~nExit.~n", [Pid]);
						{shutdown, Term} ->
		            		exit("Cannot start server for monitor : shutdown - ~p~nExit.~n", [Term]);
						Term ->
							exit("Cannot start server for monitor : ~p~nExit.~n", [Term])
					end
		    end;
		{error, Reason} ->
			exit("Cannot start server for monitor : ~p~nExit.~n", [Reason])
	end.

stop(_State) ->
	error_logger:error_msg("Msg server stops.~n").

%%%
%%% Application get stop message.
%%% Need keeping some states?
%%% Is this function proper?
%%%
app_message_processor() ->
	receive
		{stop, Msg} ->
			exit("~p~nMsgServer stops.~n", [Msg]);
		_ ->
			app_message_processor()
	end.
