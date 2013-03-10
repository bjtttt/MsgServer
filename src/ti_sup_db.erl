%%%
%%% This is for the connection to the db
%%%

-module(ti_sup_db).

-behaviour(supervisor).

-include("ti_header.hrl").

%% API
-export([start_link/3, start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

start_link(DB, Port, LSock) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [DB, Port, LSock]).

start_child() ->
    supervisor:start_child(?SERVER, []).

init([DB, Port, LSock]) ->
    DBClient = {ti_client_db, {ti_client_db, start_link, [DB, Port, LSock]}, 
              temporary, brutal_kill, worker, [ti_client_db]},
    Children = [DBClient],
    RestartStrategy = {one_for_one, ?DB_SUP_MAX, ?DB_SUP_WITHIN},
    {ok, {RestartStrategy, Children}}.
