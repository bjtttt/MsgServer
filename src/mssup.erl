%%%
%%% This is the root supervisor 
%%%

-module(mssup).

-behaviour(supervisor).

-include("header.hrl").

-export([start_link/0]).

-export([start_child_vdr/2, start_child_man/1, start_child_mp/1, start_child_mon/1, start_child_db/2]).

-export([stop_child_vdr/1, stop_child_man/1, stop_child_mp/1, stop_child_mon/1, stop_child_db/1]).

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
start_child_vdr(Socket, Addr) ->
    case supervisor:start_child(sup_vdr_handler, [Socket, Addr]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    common:loginfo("mssup:start_child_vdr fails : already_present~n");
                {already_strated, CPid} ->
                    common:loginfo("mssup:start_child_vdr fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    common:loginfo("mssup:start_child_vdr fails : ~p~n", [Msg])
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
                    common:loginfo("mssup:start_child_man fails : already_present~n");
                {already_strated, CPid} ->
                    common:loginfo("mssup:start_child_man fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    common:loginfo("mssup:start_child_man fails : ~p~n", [Msg])
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
    case supervisor:start_child(sup_mon_handler, [Socket]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    common:loginfo("mssup:start_child_mon fails : already_present~n");
                {already_strated, CPid} ->
                    common:loginfo("mssup:start_child_mon fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    common:loginfo("mssup:start_child_mon fails : ~p~n", [Msg])
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
start_child_mp(Socket) ->
    case supervisor:start_child(sup_mp_handler, [Socket]) of
        {ok, Pid} ->
            {ok, Pid};
        {ok, Pid, Info} ->
            {ok, Pid, Info};
        {error, Reason} ->
            case Reason of
                already_present ->
                    common:loginfo("mssup:start_child_mp fails : already_present~n");
                {already_strated, CPid} ->
                    common:loginfo("mssup:start_child_mp fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    common:loginfo("mssup:start_child_mp fails : ~p~n", [Msg])
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
                    common:loginfo("mssup:start_child_db(~p:~p) fails : already_present~n", [DB, PortDB]);
                {already_strated, CPid} ->
                    common:loginfo("mssup:start_child_db(~p:~p) fails : already_started PID : ~p~n", [CPid, DB, PortDB]);
                Msg ->
                    common:loginfo("mssup:start_child_db(~p:~p) fails : ~p~n", [Msg, DB, PortDB])
            end,
            {error, Reason}
    end.                    

%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_vdr(Pid) ->
    case supervisor:terminate_child(sup_vdr_handler, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            common:loginfo("mssup:stop_child_vdr(PID : ~p) fails : ~p~n", [Reason, Pid]),
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
            common:loginfo("mssup:stop_child_man(PID : ~p) fails : ~p~n", [Reason, Pid]),
            {error, Reason}
    end.
%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_mon(Pid) ->
    case supervisor:terminate_child(sup_mon_handler, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            common:loginfo("mssup:stop_child_mon fails(PID : ~p) : ~p~n", [Reason, Pid]),
            {error, Reason}
    end.
%%%
%%% ok
%%% {error, Error} : Error = not_found | simple_one_for_one
%%%
stop_child_mp(Pid) ->
    case supervisor:terminate_child(sup_mp_handler, Pid) of
        ok ->
            ok;
        {error, Reason} ->
            common:loginfo("mssup:stop_child_mp fails(PID : ~p) : ~p~n", [Reason, Pid]),
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
            common:loginfo("mssup:stop_child_db fails(PID : ~p) : ~p~n", [Reason, Pid]),
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
            common:loginfo("mssup:start_link : ignore~n"),
            ignore;
        {error, Reason} ->
            case Reason of
                {shutdown, Info} ->
                    common:loginfo("mssup:start_link fails : shutdown : ~p~n", [Info]);
                {already_strated, CPid} ->
                    common:loginfo("mssup:start_link fails : already_started PID : ~p~n", [CPid]);
                Msg ->
                    common:loginfo("mssup:start_link fails : ~p~n", [Msg])
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
    [{maxr, MaxR}] = ets:lookup(msgservertable, maxr),
    [{maxt, MaxT}] = ets:lookup(msgservertable, maxt),
    [{mode, Mode}] = ets:lookup(msgservertable, mode),
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
    % Create WS client
    WSClient  = {
                 wsock_client,                               % Id       = internal id
                 {wsock_client, start, [WS, PortWS, "/"]},   % StartFun = {M, F, A}
                 permanent,                                         % Restart  = permanent | transient | temporary
                 ?TIME_TERMINATE_MAN,                               % Shutdown = brutal_kill | int() >= 0 | infinity
                 worker,                                            % Type     = worker | supervisor
                 [wsock_client]                                     % Modules  = [Module] | dynamic
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
	if
		Mode == 2 ->
    		Children = [VDRServer, VDRHandler, MonServer, MonHandler, DBClient, WSClient],%, Iconv],
		    RestartStrategy = {one_for_one, MaxR, MaxT},
		    {ok, {RestartStrategy, Children}};
		Mode == 1 ->
    		Children = [VDRServer, VDRHandler, MonServer, MonHandler, DBClient],%, Iconv],
		    RestartStrategy = {one_for_one, MaxR, MaxT},
		    {ok, {RestartStrategy, Children}};
		true ->
     		Children = [VDRServer, VDRHandler, MonServer, MonHandler],%, Iconv],
		    RestartStrategy = {one_for_one, MaxR, MaxT},
		    {ok, {RestartStrategy, Children}}
	end;
    %Children = [VDRServer, VDRHandler, MonServer, MonHandler, WSClient],
    %Children = [VDRServer, VDRHandler, MonServer, MonHandler, DBClient],
    %Children = [VDRServer, VDRHandler, MonServer, MonHandler],
    %RestartStrategy = {one_for_one, MaxR, MaxT},
    %{ok, {RestartStrategy, Children}};
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
