%%%
%%% This is for the connection from the VDR
%%%

-module(ti_sup_vdr).

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

init([]) ->
    VDRServer = {ti_server_vdr, {ti_server_vdr, start_link, []}, 
              temporary, brutal_kill, worker, [ti_server_vdr]},
    Children = [VDRServer],
    RestartStrategy = {simple_one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
