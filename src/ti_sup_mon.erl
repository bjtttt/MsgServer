%%%
%%% This is for the connection from the monitor
%%%

-module(ti_sup_mon).

-behaviour(supervisor).

%% API
-export([start_link/1, start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

start_link(LSock) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [LSock]).

start_child() ->
    supervisor:start_child(?SERVER, []).

init([LSock]) ->
    MonServer = {ti_server_mon, {ti_server_mon, start_link, [LSock]}, 
              temporary, brutal_kill, worker, [ti_server_mon]},
    Children = [MonServer],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
