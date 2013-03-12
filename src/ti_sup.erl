%%%
%%% This is the root supervisor 
%%%

-module(ti_sup).

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

%%%
%%% In the DEV phase, Max is 0 and Within is 1
%%% After release, they should be adjusted to proper values.
%%%
init([]) ->
    [{portvdr, PortVDR}] = ets:lookup(msgservertable, portvdr),
    VDRServer = {
				 ti_server_vdr,                             % Id       = internal id
				 {ti_server_vdr, start_link, [PortVDR]},    % StartFun = {M, F, A}
				 temporary,                                 % Restart  = permanent | transient | temporary
				 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
				 worker,                                    % Type     = worker | supervisor
				 [ti_server_vdr]                            % Modules  = [Module] | dynamic
				},
    VDRHandler = {
				  ti_sup_handler_vdr,
				  {supervisor, start_link, [{local, ti_sup_handler_vdr}, ?MODULE, [ti_handler_vdr]]},
				  permanent, 						% Restart  = permanent | transient | temporary
				  brutal_kill, 					    % Shutdown = brutal_kill | int() >= 0 | infinity
				  supervisor, 				    	% Type     = worker | supervisor
				  []								% Modules  = [Module] | dynamic
				 },
	Children = [VDRServer, VDRHandler],
    %ManServer = {ti_sup_man, {ti_sup_man, start_link, []}, 
    %             permanent, brutal_kill, supervisor, [ti_server_man]},
    %MonServer = {ti_sup_mon, {ti_sup_mon, start_link, []}, 
    %             permanent, brutal_kill, supervisor, [ti_server_mon]},
    %DBClient = {ti_sup_db, {ti_sup_db, start_link, []}, 
    %            permanent, brutal_kill, supervisor, [ti_client_db]},
    %Children = [VDRServer, ManServer, MonServer, DBClient],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.

init ([Module]) ->
    {ok,
     {_SupFlags = {simple_one_for_one, 0, 1},
      [
                                                % TCP Client
       {   undefined,                               % Id       = internal id
           {Module,start_link,[]},                  % StartFun = {M, F, A}
           temporary,                               % Restart  = permanent | transient | temporary
           2000,                                    % Shutdown = brutal_kill | int () >= 0 | infinity
           worker,                                  % Type     = worker | supervisor
           []                                       % Modules  = [Module] | dynamic
       }]
     }
    }.




