%%%
%%% This is for the connection to the db
%%%

-module(ti_sup_db).

-behaviour(supervisor).

-include("ti_common.hrl").

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
    Server = {ti_client_db, {ti_client_db, start_link, [DB, Port]},
              temporary, brutal_kill, worker, [ti_client_db]},
    Children = [Server],
    RestartStrategy = {simple_one_for_one, ?DB_SUP_MAX, ?DB_SUP_WITHIN},
    {ok, {RestartStrategy, Children}}.
