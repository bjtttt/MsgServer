%%%
%%% This is the root supervisor 
%%%

-module(mssup).

-behaviour(supervisor).

-include("header.hrl").

-export([start_link/0]).

-export([init/1]).

-define(SERVER, ?MODULE).

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
            common:logerror("mssup:start_link : ignore~n"),
            ignore;
        {error, Reason} ->
            case Reason of
                {shutdown, Info} ->
                    common:logerror("mssup:start_link fails : shutdown : ~p~n", [Info]);
                {already_strated, CPid} ->
                    common:logerror("mssup:start_link fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    common:logerror("mssup:start_link fails : ~p~n", [Msg])
            end,
            {error, Reason}
    end.

init([]) ->
    [{portvdr, PortVDR}] = ets:lookup(msgservertable, portvdr),
    [{portmon, PortMon}] = ets:lookup(msgservertable, portmon),
    %[{portmp, PortMP}] = ets:lookup(msgservertable, portmp),
    [{ws, WS}] = ets:lookup(msgservertable, ws),
    [{portws, PortWS}] = ets:lookup(msgservertable, portws),
    [{db, DB}] = ets:lookup(msgservertable, db),
    [{dbname, DBName}] = ets:lookup(msgservertable, dbname),
    [{dbuid, DBUid}] = ets:lookup(msgservertable, dbuid),
    [{dbpwd, DBPwd}] = ets:lookup(msgservertable, dbpwd),
    % Listen VDR connection
    VDRServer = {
				 vdr_server,                             % Id       = internal id
				 {vdr_server, start_link, [PortVDR]},    % StartFun = {M, F, A}
				 permanent,                                 % Restart  = permanent | transient | temporary
				 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
				 worker,                                    % Type     = worker | supervisor
				 [vdr_server]                            % Modules  = [Module] | dynamic
				},
    % Process VDR communication
    VDRHandler = {
				  sup_vdr_handler,               % Id       = internal id
				  {supervisor, start_link, [{local, sup_vdr_handler}, ?MODULE, [vdr_handler]]},
				  permanent, 						% Restart  = permanent | transient | temporary
				  ?TIME_TERMINATE_VDR, 				% Shutdown = brutal_kill | int() >= 0 | infinity
				  supervisor, 				    	% Type     = worker | supervisor
				  []								% Modules  = [Module] | dynamic
				 },
    % Listen Monitor connection
    MonServer = {
                 mon_server,                             % Id       = internal id
                 {mon_server, start_link, [PortMon]},    % StartFun = {M, F, A}
                 permanent,                                 % Restart  = permanent | transient | temporary
                 brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                    % Type     = worker | supervisor
                 [mon_server]                            % Modules  = [Module] | dynamic
                },
    % Process Monitor communication
    MonHandler = {
                  sup_mon_handler,               % Id       = internal id
                  {supervisor, start_link, [{local, sup_mon_handler}, ?MODULE, [mon_handler]]},
                  permanent,                        % Restart  = permanent | transient | temporary
                  ?TIME_TERMINATE_MON,              % Shutdown = brutal_kill | int() >= 0 | infinity
                  supervisor,                       % Type     = worker | supervisor
                  []                                % Modules  = [Module] | dynamic
                 },
    % Listen MP connection
    %MPServer = {
    %             mp_server,                             % Id       = internal id
    %             {mp_server, start_link, [PortMP]},    % StartFun = {M, F, A}
    %             permanent,                                 % Restart  = permanent | transient | temporary
    %             brutal_kill,                               % Shutdown = brutal_kill | int() >= 0 | infinity
    %             worker,                                    % Type     = worker | supervisor
    %             [mp_server]                            % Modules  = [Module] | dynamic
    %            },
    % Process MP communication
    %MPHandler = {
    %              sup_mp_handler,               % Id       = internal id
    %              {supervisor, start_link, [{local, sup_mp_handler}, ?MODULE, [mp_handler]]},
    %              permanent,                        % Restart  = permanent | transient | temporary
    %              ?TIME_TERMINATE_MP,              % Shutdown = brutal_kill | int() >= 0 | infinity
    %              supervisor,                       % Type     = worker | supervisor
    %              []                                % Modules  = [Module] | dynamic
    %             },
    % Create DB client
    DBClient  = {
                 mysql,                              % Id       = internal id
                 {mysql, start_link, [conn, DB, ?DEF_PORT_DB, DBUid, DBPwd, DBName, undefined, utf8]},  % StartFun = {M, F, A}
                 permanent,                                 % Restart  = permanent | transient | temporary
                 ?TIME_TERMINATE_DB,                        % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                    % Type     = worker | supervisor
                 [mysql]                             % Modules  = [Module] | dynamic
                },
    % Create WS client
    WSClient  = {
                 wsock_client,                               % Id       = internal id
                 {wsock_client, start, [WS, PortWS, "/"]},   % StartFun = {M, F, A}
                 permanent,                                         % Restart  = permanent | transient | temporary
                 ?TIME_TERMINATE_MAN,                               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                            % Type     = worker | supervisor
                 [wsock_client]                                     % Modules  = [Module] | dynamic
                },
    % Create iconv
    %Iconv  = {
    %             iconv,                               % Id       = internal id
    %             {iconv, start, []},   % StartFun = {M, F, A}
    %             permanent,                                         % Restart  = permanent | transient | temporary
    %             ?TIME_TERMINATE_ICONV,                               % Shutdown = brutal_kill | int() >= 0 | infinity
    %             worker,                                            % Type     = worker | supervisor
    %             [iconv]                                     % Modules  = [Module] | dynamic
    %            },
    %Children = [VDRServer, VDRHandler, ManServer, ManHandler, MonServer, MonHandler, DBClient],
    %Children = [VDRServer, VDRHandler, MPServer, MPHandler, MonServer, MonHandler, DBClient, WSClient],%, Iconv],
    Children = [VDRServer, VDRHandler, MonServer, MonHandler, DBClient, WSClient],%, Iconv],
    %Children = [VDRServer, VDRHandler, MonServer, MonHandler, WSClient],
    %Children = [VDRServer, VDRHandler, MonServer, MonHandler, DBClient],
    %Children = [VDRServer, VDRHandler, MonServer, MonHandler],
    RestartStrategy = {one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}};
%%%
%%% I don't know what this function for. :-(
%%% However, it is necessary.
%%%
init ([Module]) ->
    Instance = {
                 undefined,                 % Id       = internal id
                 {Module, start_link, []},  % StartFun = {M, F, A}
                 temporary,                 % Restart  = permanent | transient | temporary
                 brutal_kill,               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                    % Type     = worker | supervisor
                 []                         % Modules  = [Module] | dynamic
                },
    Children = [Instance],
    RestartStrategy = {simple_one_for_one, 0, 1},
    {ok, {RestartStrategy, Children}}.

%log(Module, Line, Level, FormatFun) ->
%    case Level of
%    error ->
%        {Format, Arguments} = FormatFun(),
%        io:format("~w:~b: "++ Format ++ "~n", [Module, Line] ++ Arguments);
%    _ -> o
%   end.
