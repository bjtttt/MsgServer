-module(ti_app).

-behaviour(application).

-export([start/0, start/2, stop/1]).

-define(DEF_PORT, 6000).
-define(DEF_PORT_MAN, 6001).
-define(DEF_DB, "127.0.0.1").
-define(DEF_PORT_DB, 6002).

start() ->
	start(normal, [?DEF_PORT, ?DEF_PORT_MAN, ?DEF_DB, ?DEF_PORT_DB]).

%start(_StartType, _StartArgs) ->
start(_StartType, StartArgs) ->
	[DefPort, DefPortMan, DefDB, DefPortDB] = StartArgs,
    %Port = case application:get_env(tcp_interface, port) of
    %           {ok, P} -> P;
    %           undefined -> ?DEF_PORT
    %       end,
	ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
	case ti_sup_db:start_link(DefDB, DefPortDB) of
        {ok, PidDB} ->
            ti_sup:start_child(),
            ets:insert(serverstatetable,{dbsuppid,PidDB}),
			case gen_tcp:listen(DefPortMan, [{active, true}]) of
				{ok, LSockMan} ->
				    case ti_sup_man:start_link() of
				        {ok, PidMan} ->
				            ti_sup:start_child(LSockMan),
            				ets:insert(serverstatetable,{mansuppid,PidMan}),
						    {ok, LSock} = gen_tcp:listen(DefPort, [{active, true}]),
						    case ti_sup:start_link(LSock) of
						        {ok, Pid} ->
            						ets:insert(serverstatetable,{suppid,Pid}),
						            ti_sup:start_child(),
						            {ok, "Success!"};
						        Other ->
									error_logger:error_msg("Cannot start listen from the VDR : ~p~nExit.~n", Other),
						            {error, Other}
						    end;
				        OtherMan ->
							error_logger:error_msg("Cannot start listen from the management server : ~p~nExit.~n", OtherMan),
				            {error, OtherMan}
				    end;
				{error, ReasonMan} ->
					error_logger:error_msg("Cannot start listen from the management server : ~p~nExit.~n", ReasonMan),
					{error, ReasonMan}
			end;
        OtherDB ->
			error_logger:error_msg("Cannot start connection to the database : ~p:~p~nExit.~n", [OtherDB, DefPortDB]),
            {error, OtherDB}
    end.

stop(_State) ->
    ok.
