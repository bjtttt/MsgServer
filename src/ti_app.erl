-module(ti_app).

-behaviour(application).

-export([start/0, start/2, stop/1]).

-define(DEF_PORT, 6000).
-define(DEF_MAN_PORT, 6001).
-define(DEF_MAN, "127.0.0.1").
-define(DEF_DB_PORT, 6002).
-define(DEF_DB, "127.0.0.1").

start() ->
	start("", [?DEF_MAN, ?DEF_DB]).

start(_StartType, _StartArgs) ->
    Port = case application:get_env(tcp_interface, port) of
               {ok, P} -> P;
               undefined -> ?DEF_PORT
           end,
    case ti_sup_man:start_link() of
        {ok, PidMan} ->
            ti_sup:start_child(),
            {ok, PidMan};
        OtherMan ->
			error_logger:error_msg("Cannot start connection to the management server : ~p~n", OtherMan),
			error_logger:error_msg("Error message : ~p~nExit.~n", OtherMan),
            %{error, OtherMan}
			exit(OtherMan)
    end,
    case ti_sup_db:start_link() of
        {ok, PidDB} ->
            ti_sup:start_child(),
            {ok, PidDB};
        OtherDB ->
			error_logger:error_msg("Cannot start connection to the database : ~p~n", OtherDB),
			error_logger:error_msg("Error message : ~p~nExit.~n", OtherDB),
            %{error, OtherDB}
			exit(OtherDB)
    end,
    {ok, LSock} = gen_tcp:listen(Port, [{active, true}]),
    case ti_sup:start_link(LSock) of
        {ok, Pid} ->
            ti_sup:start_child(),
            {ok, Pid};
        Other ->
            {error, Other}
    end.

stop(_State) ->
    ok.
