%%%
%%% This is for the connection to the db
%%%

-module(ti_sup_db).

-behaviour(supervisor).

%% API
-export([start_link/2, start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

%start_link(LSock) ->
%    supervisor:start_link({local, ?SERVER}, ?MODULE, [LSock]).
start_link(DB, Port) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [DB, Port]).

start_child() ->
    supervisor:start_child(?SERVER, []).

init([DB, Port]) ->
    Server = {ti_server_db, {ti_server_db, start_link, [DB, Port]},
              temporary, brutal_kill, worker, [ti_server_db]},
    Children = [Server],
    RestartStrategy = {simple_one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
