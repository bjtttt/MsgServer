%%%
%%% This is for the connection to the db
%%%

-module(ti_sup_db).

-behaviour(supervisor).

%% API
-export([start_link/3, start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%start_link(LSock) ->
%    supervisor:start_link({local, ?SERVER}, ?MODULE, [LSock]).
start_link(LSock, DB, Port) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [LSock, DB, Port]).

start_child() ->
    supervisor:start_child(?SERVER, []).

init([LSock, _DB, _Port]) ->
    Server = {ti_server, {ti_server, start_link, [LSock]},
              temporary, brutal_kill, worker, [ti_server]},
    Children = [Server],
    RestartStrategy = {simple_one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
