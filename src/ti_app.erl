-module(ti_app).

-behaviour(application).

-include("ti_common.hrl").

-export([start/0, start/2, stop/1]).

start() ->
	start(normal, [?DEF_PORT, ?DEF_PORT_MAN, ?DEF_DB, ?DEF_PORT_DB]).

%%
%% Steps :
%%     1. Start connection to DB
%%     2. Start server for management
%%     3. Start server for VDR
%%     4. Start server for monitor (not implemented yet)
%%
%%  msgservertable : common states
%%  vdrinittable, vdrtable : when VDR connects, keep its socket as key in vdrinittable first.
%%                           after receiving VDR ID, the entry will be moved to vdrtable and use VDR ID as key instead.
%%  mantable : 
%%
start(_StartType, StartArgs) ->
	[DefPort, DefPortMan, DefDB, DefPortDB] = StartArgs,
	ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(vdrinittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(vdrtable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	ets:new(mantable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	% if dbconncount reaches DB_CONN_CNT_MAX, msgserver will stop
	ets:insert(serverstatetable,{dbconncount,0}),
	% make sure that msgserver can get stop message from any internal process
    ets:insert(serverstatetable,{apppid,self()}),
	PidAppMsg = spawn(fun() -> app_message_processor() end),
    ets:insert(serverstatetable,{appmsgpid,PidAppMsg}),
	% start DB client
	case ti_sup_db:start_link(DefDB, DefPortDB) of
        {ok, PidDB} ->
            ets:insert(serverstatetable,{dbsuppid,PidDB}),
            ti_sup:start_child(),
			% start management server 
			case gen_tcp:listen(DefPortMan, [{active, true}]) of
				{ok, LSockMan} ->
				    case ti_sup_man:start_link(LSockMan) of
				        {ok,PidMan} ->
            				ets:insert(serverstatetable,{mansuppid,PidMan}),
				            ti_sup:start_child(LSockMan),
							% start VDR server
							case gen_tcp:listen(DefPort, [{active, true}]) of
								{ok, LSock} ->
								    case ti_sup:start_link(LSock) of
								        {ok, Pid} ->
		            						ets:insert(serverstatetable,{suppid,Pid}),
								            ti_sup:start_child(LSock),
											% start monitor server
											% not implemented yet
											ok;
								        _ ->
											error_logger:error_msg("Cannot start server for VDR.~nExit.~n"),
								            error 
								    end;
								{error, Reason} ->
									error_logger:error_msg("Cannot start listen from VDR : ~p~nExit.~n", Reason),
									{error, Reason}
							end;
				        _ ->
							error_logger:error_msg("Cannot start server for management.~nExit.~n"),
				            error
				    end;
				{error, ReasonMan} ->
					error_logger:error_msg("Cannot start listen from management : ~p~nExit.~n", ReasonMan),
					{error, ReasonMan}
			end;
        _ ->
			error_logger:error_msg("Cannot start connection to DB : ~p:~p~nExit.~n", [DefDB, DefPortDB]),
            error
    end.

stop(_State) ->
    ok.

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
