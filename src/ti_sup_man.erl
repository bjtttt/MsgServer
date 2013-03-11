%%%
%%% This is for the connection to the manangement server.
%%% Message format : JSON
%%%

-module(ti_sup_man).

-behaviour(supervisor).

%% API
-export([start_link/0, start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

start_child() ->
    supervisor:start_child(?SERVER, []).

init([LSock]) ->
    ManServer = {ti_server_man, {ti_server_man, start_link, [LSock]}, 
              temporary, brutal_kill, worker, [ti_server_man]},
    Children = [ManServer],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
