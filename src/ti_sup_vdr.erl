%%%
%%% This is for the connection from the VDR
%%%

-module(ti_sup_vdr).

-behaviour(supervisor).

%% API
-export([start_link/1, start_child/1]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

start_link(CSock) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [CSock]).

start_child(CSock) ->
    supervisor:start_child(?SERVER, [CSock]).

init([CSock]) ->
    VDRHandler = {
                  ti_handler_vdr,                           % Id       = internal id
                  {ti_handler_vdr, start_link, [CSock]},    % StartFun = {M, F, A}
                  temporary,                                % Restart  = permanent | transient | temporary
                  brutal_kill,                              % Shutdown = brutal_kill | int() >= 0 | infinity
                  worker,                                   % Type     = worker | supervisor
                  [ti_handler_vdr]                          % Modules  = [Module] | dynamic
                 },
    Children = [VDRHandler],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
