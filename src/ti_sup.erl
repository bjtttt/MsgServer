%%%
%%% This is the root supervisor 
%%%

-module(ti_sup).

-behaviour(supervisor).

-export([start_link/0, start_child_vdr/1, start_child_man/1, start_child_mon/1]).

-export([init/1]).

-define(SERVER, ?MODULE).

%%% 
%%% startchild_ret() = {ok, Child :: child()}
%%%                  | {ok, Child :: child(), Info :: term()}
%%%                  | {error, startchild_err()}
%%% startchild_err() = already_present
%%%                  | {already_started, Child :: child()}
%%%                  | term()
%%% 
start_child_vdr(CSock) ->
    supervisor:start_child(ti_sup_handler_vdr, [CSock]).
start_child_man(CSock) ->
    supervisor:start_child(ti_sup_handler_man, [CSock]).
start_child_mon(CSock) ->
    supervisor:start_child(ti_sup_handler_mon, [CSock]).
    
start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

init([]) ->
    % VDR
    [{portvdr, PortVDR}] = ets:lookup(msgservertable, portvdr),
    [{portman, PortMan}] = ets:lookup(msgservertable, portman),
    [{portmon, PortMon}] = ets:lookup(msgservertable, portmon),
    % Listen VDR connection
    VDRServer = {
				 ti_server_vdr,                             % Id       = internal id
				 {ti_server_vdr, start_link, [PortVDR]},    % StartFun = {M, F, A}
				 permanent,                                 % Restart  = permanent | transient | temporary
				 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
				 worker,                                    % Type     = worker | supervisor
				 [ti_server_vdr]                            % Modules  = [Module] | dynamic
				},
    % Process VDR communication
    VDRHandler = {
				  ti_sup_handler_vdr,               % Id       = internal id
				  {supervisor, start_link, [{local, ti_sup_handler_vdr}, ?MODULE, [ti_handler_vdr]]},
				  permanent, 						% Restart  = permanent | transient | temporary
				  brutal_kill, 					    % Shutdown = brutal_kill | int() >= 0 | infinity
				  supervisor, 				    	% Type     = worker | supervisor
				  []								% Modules  = [Module] | dynamic
				 },
    % Listen Management connection
    ManServer = {
                 ti_server_man,                             % Id       = internal id
                 {ti_server_man, start_link, [PortMan]},    % StartFun = {M, F, A}
                 permanent,                                 % Restart  = permanent | transient | temporary
                 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                    % Type     = worker | supervisor
                 [ti_server_man]                            % Modules  = [Module] | dynamic
                },
    % Process Management communication
    ManHandler = {
                  ti_sup_handler_man,               % Id       = internal id
                  {supervisor, start_link, [{local, ti_sup_handler_man}, ?MODULE, [ti_handler_man]]},
                  permanent,                        % Restart  = permanent | transient | temporary
                  brutal_kill,                      % Shutdown = brutal_kill | int() >= 0 | infinity
                  supervisor,                       % Type     = worker | supervisor
                  []                                % Modules  = [Module] | dynamic
                 },
    % Listen Monitor connection
    MonServer = {
                 ti_server_mon,                             % Id       = internal id
                 {ti_server_mon, start_link, [PortMon]},    % StartFun = {M, F, A}
                 permanent,                                 % Restart  = permanent | transient | temporary
                 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                    % Type     = worker | supervisor
                 [ti_server_mon]                            % Modules  = [Module] | dynamic
                },
    % Process Monitor communication
    MonHandler = {
                  ti_sup_handler_mon,               % Id       = internal id
                  {supervisor, start_link, [{local, ti_sup_handler_mon}, ?MODULE, [ti_handler_mon]]},
                  permanent,                        % Restart  = permanent | transient | temporary
                  brutal_kill,                      % Shutdown = brutal_kill | int() >= 0 | infinity
                  supervisor,                       % Type     = worker | supervisor
                  []                                % Modules  = [Module] | dynamic
                 },
    %DBClient = {ti_sup_db, {ti_sup_db, start_link, []}, 
    %            permanent, brutal_kill, supervisor, [ti_client_db]},
    %Children = [VDRServer, ManServer, MonServer, DBClient],
    Children = [VDRServer, VDRHandler, ManServer, ManHandler, MonServer, MonHandler],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}};
%%%
%%% I don't know what this function for. :-(
%%% However, it is necessary.
%%%
init ([Module]) ->
    VDRClient = {
                 undefined,                 % Id       = internal id
                 {Module, start_link, []},  % StartFun = {M, F, A}
                 temporary,                 % Restart  = permanent | transient | temporary
                 brutal_kill,               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                    % Type     = worker | supervisor
                 []                         % Modules  = [Module] | dynamic
                },
    Children = [VDRClient],
    RestartStrategy = {simple_one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.



