%%%
%%% This is the root supervisor 
%%%

-module(ti_sup).

-behaviour(supervisor).

-export([start_link/0, start_child/1]).

-export([init/1]).

-define(SERVER, ?MODULE).

start_link() ->
    supervisor:start_link({local, ?SERVER}, ?MODULE, []).

start_child(Module) ->
    case Module of
        "VDR" ->
            supervisor:start_child(ti_sup_handler_vdr, []);
        _ ->
            TimeStamp = calendar:now_to_local_time(erlang:now()),
            Format = "~p : ti_sup:start_child(~p, Socket) : First parameter error~n",
            error_logger:error_msg(Format, [TimeStamp, Module])
    end.

init([]) ->
    % VDR
    [{portvdr, PortVDR}] = ets:lookup(msgservertable, portvdr),
    % Listen VDR connection
    VDRServer = {
				 ti_sup_server_vdr,                         % Id       = internal id
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
	Children = [VDRServer, VDRHandler],
    %ManServer = {ti_sup_man, {ti_sup_man, start_link, []}, 
    %             permanent, brutal_kill, supervisor, [ti_server_man]},
    %MonServer = {ti_sup_mon, {ti_sup_mon, start_link, []}, 
    %             permanent, brutal_kill, supervisor, [ti_server_mon]},
    %DBClient = {ti_sup_db, {ti_sup_db, start_link, []}, 
    %            permanent, brutal_kill, supervisor, [ti_client_db]},
    %Children = [VDRServer, ManServer, MonServer, DBClient],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}};
%%%
%%% I don't know what this function for. :-(
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



