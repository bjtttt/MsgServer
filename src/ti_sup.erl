%%%
%%% This is the root supervisor 
%%%

-module(ti_sup).

-behaviour(supervisor).

-export([start_link/0]).

-export([start_child_vdr/1, start_child_man/1, start_child_mon/1, start_child_db/2]).

-export([stop_child_vdr/1, stop_child_man/1, stop_child_mon/1, stop_child_db/1]).

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
start_child_vdr(Socket) ->
    case supervisor:start_child(ti_sup_handler_vdr, [Socket]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    ti_common:logerror("ti_sup:start_child_vdr fails : already_present~n");
                {already_strated, CPid} ->
                    ti_common:logerror("ti_sup:start_child_vdr fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    ti_common:logerror("ti_sup:start_child_vdr fails : ~p~n", [Msg])
            end,
            {error, Reason}
    end.                    
%%% 
%%% startchild_ret() = {ok, Child :: child()}
%%%                  | {ok, Child :: child(), Info :: term()}
%%%                  | {error, startchild_err()}
%%% startchild_err() = already_present
%%%                  | {already_started, Child :: child()}
%%%                  | term()
%%% 
start_child_man(Socket) ->
    case supervisor:start_child(ti_sup_handler_man, [Socket]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    ti_common:logerror("ti_sup:start_child_man fails : already_present~n");
                {already_strated, CPid} ->
                    ti_common:logerror("ti_sup:start_child_man fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    ti_common:logerror("ti_sup:start_child_man fails : ~p~n", [Msg])
            end,
            {error, Reason}
    end.                    
%%% 
%%% startchild_ret() = {ok, Child :: child()}
%%%                  | {ok, Child :: child(), Info :: term()}
%%%                  | {error, startchild_err()}
%%% startchild_err() = already_present
%%%                  | {already_started, Child :: child()}
%%%                  | term()
%%% 
start_child_mon(Socket) ->
    case supervisor:start_child(ti_sup_handler_mon, [Socket]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    ti_common:logerror("ti_sup:start_child_mon fails : already_present~n");
                {already_strated, CPid} ->
                    ti_common:logerror("ti_sup:start_child_mon fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    ti_common:logerror("ti_sup:start_child_mon fails : ~p~n", [Msg])
            end,
            {error, Reason}
    end.                    
%%% 
%%% startchild_ret() = {ok, Child :: child()}
%%%                  | {ok, Child :: child(), Info :: term()}
%%%                  | {error, startchild_err()}
%%% startchild_err() = already_present
%%%                  | {already_started, Child :: child()}
%%%                  | term()
%%% 
start_child_db(DB, PortDB) ->
    case supervisor:start_child(ti_client_db, [DB, PortDB]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    ti_common:logerror("ti_sup:start_child_db(~p:~p) fails : already_present~n", [DB, PortDB]);
                {already_strated, CPid} ->
                    ti_common:logerror("ti_sup:start_child_db(~p:~p) fails : already_started PID : ~p~n", [CPid, DB, PortDB]);
                Msg ->
                    ti_common:logerror("ti_sup:start_child_db(~p:~p) fails : ~p~n", [Msg, DB, PortDB])
            end,
            {error, Reason}
    end.                    

%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_vdr(Pid) ->
    case supervisor:terminate_child(ti_sup_handler_vdr, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            ti_common:logerror("ti_sup:stop_child_vdr(PID : ~p) fails : ~p~n", [Reason, Pid]),
            {error, Reason}
    end.
%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_man(Pid) ->
    case supervisor:terminate_child(ti_sup_handler_man, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            ti_common:logerror("ti_sup:stop_child_man(PID : ~p) fails : ~p~n", [Reason, Pid]),
            {error, Reason}
    end.
%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_mon(Pid) ->
    case supervisor:terminate_child(ti_sup_handler_mon, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            ti_common:logerror("ti_sup:stop_child_mon fails(PID : ~p) : ~p~n", [Reason, Pid]),
            {error, Reason}
    end.
%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_db(Pid) ->
    case supervisor:terminate_child(ti_client_db, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            ti_common:logerror("ti_sup:stop_child_db fails(PID : ~p) : ~p~n", [Reason, Pid]),
            {error, Reason}
    end.

%%%
%%% startlink_ret() = {ok, pid()}
%%%                 | ignore
%%%                 | {error, startlink_err()}
%%% startlink_err() = {already_started, pid()}
%%%                 | {shutdown, term()}
%%%                 | term()
%%%
start_link() ->
    case supervisor:start_link({local, ?SERVER}, ?MODULE, []) of
        {ok, Pid} ->
            {ok, Pid};
        ignore ->
            ti_common:logerror("ti_sup:start_link : ignore~n"),
            ignore;
        {error, Reason} ->
            case Reason of
                {shutdown, Info} ->
                    ti_common:logerror("ti_sup:start_link fails : shutdown : ~p~n", [Info]);
                {already_strated, CPid} ->
                    ti_common:logerror("ti_sup:start_link fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    ti_common:logerror("ti_sup:start_link fails : ~p~n", [Msg])
            end,
            {error, Reason}
    end.

init([]) ->
    % VDR
    [{portvdr, PortVDR}] = ets:lookup(msgservertable, portvdr),
    [{portman, PortMan}] = ets:lookup(msgservertable, portman),
    [{portmon, PortMon}] = ets:lookup(msgservertable, portmon),
    [{db, DB}] = ets:lookup(msgservertable, db),
    [{portdb, PortDB}] = ets:lookup(msgservertable, portdb),
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
    % Listen Monitor connection
    DBClient  = {
                 ti_client_db,                              % Id       = internal id
                 {ti_client_db, start_link, [DB, PortDB]},  % StartFun = {M, F, A}
                 permanent,                                 % Restart  = permanent | transient | temporary
                 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                    % Type     = worker | supervisor
                 [ti_client_db]                             % Modules  = [Module] | dynamic
                },
    Children = [VDRServer, VDRHandler, ManServer, ManHandler, MonServer, MonHandler, DBClient],
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



