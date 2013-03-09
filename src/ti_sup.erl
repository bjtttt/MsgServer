%%%
%%% This is the root supervisor 
%%%

-module(ti_sup).

-behaviour(supervisor).

%% API
-export([start_link/1, start_child/0]).

%% Supervisor callbacks
-export([init/1]).

-define(SERVER, ?MODULE).

start_link(StartArgs) ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, [StartArgs]).

start_child() ->
    supervisor:start_child(?SERVER, []).

%%%
%%% In the DEV phase, Max is 0 and Within is 1
%%% After release, they should be adjusted to proper values.
%%%
init([StartArgs]) ->
	[PortVDR, PortMan, PortMon, DB, PortDB, LSock] = StartArgs,
    % Children definitions
    VDRServer = {ti_server_vdr, {ti_server_vdr, start_link, [PortVDR]}, permanent, brutal_kill, supervisor, [ti_server_vdr]},
    ManServer = {ti_server_man, {ti_server_man, start_link, [PortMan]}, permanent, brutal_kill, supervisor, [ti_server_man]},
    DBClient = {ti_client_db, {ti_client_db, start_link, [DB, PortDB, LSock]}, permanent, brutal_kill, supervisor, [ti_client_db]},
    MonServer = {ti_server_mon, {ti_server_mon, start_link, [PortMon]}, permanent, brutal_kill, supervisor, [ti_server_mon]},
    Children = [VDRServer, ManServer, DBClient, MonServer],
    RestartStrategy = {simple_one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.
