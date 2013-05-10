%%%
%%% Need considering how management server sends message to Management
%%%

-module(mon_server).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, 
         handle_info/2, terminate/2, code_change/3]). 

-include("header.hrl").

%%%
%%% In fact, we can get PortVDR from msgservertable.
%%% Here, the reason that we use parameter is for efficiency.
%%%
%%% Result = {ok,Pid} | ignore | {error,Error}
%%%    Pid = pid()
%%%  Error = {already_started,Pid} | term()
%%%
start_link(PortMon) ->  
    case gen_server:start_link({local, ?MODULE}, ?MODULE, [PortMon], []) of
        {ok, Pid} ->
            {ok, Pid};
        ignore ->
            common:logerror("ti_sup:start_child_mon(~p) fails : ignore~n", [PortMon]),
            ignore;
        {already_started, Pid} ->
            common:logerror("ti_sup:start_child_mon(~p) fails : already_started : ~p~n", [PortMon, Pid]),
            {already_started, Pid}
    end.

%%%
%%% {backlog, 30} specifies the length of the OS accept queue. 
%%%
init([PortMon]) ->    
    process_flag(trap_exit, true),    
    Opts = [binary, {packet, 0}, {reuseaddr, true}, {keepalive, true}, {active, once}],    
    % Management server start listening
    case gen_tcp:listen(PortMon, Opts) of       
        {ok, LSock} -> 
            % Create first accepting process            
            case prim_inet:async_accept(LSock, -1) of
                {ok, Ref} ->
                    {ok, #serverstate{lsock=LSock, acceptor=Ref}};
                Error ->
                    common:logerror("Management server prim_inet:async_accept accept fails : ~p~n", [Error]),
                    {stop, Error}
            end;
        {error, Reason} ->          
            common:logerror("Monitor server gen_tcp:listen fails : ~p~n", [Reason]),
            {stop, Reason}    
    end. 

handle_call(Request, _From, State) ->    
    {stop, {unknown_call, Request}, State}.

handle_cast(_Msg, State) ->    
    {noreply, State}. 

handle_info({inet_async, LSock, Ref, {ok, CSock}}, #serverstate{lsock=LSock, acceptor=Ref}=State) ->
    common:printsocketinfo(CSock, "Accepted a monitor from"),
    try        
        case common:set_sockopt(LSock, CSock, "Monitor Server") of            
            ok -> 
                ok;         
            {error, Reason} -> 
                common:logerror("Monitor server set_sockopt fails : ~p~n", [Reason]),
                % Why use exit here?
                % {stop, set_sockpt, Reason}
                % Please consider it in the future
                exit({set_sockopt, Reason})       
        end,
        % New client connected
        % Spawn a new process using the simple_one_for_one supervisor.
        % Why it is "the simple_one_for_one supervisor"?
        case ti_sup:start_child_mon(CSock) of
            {ok, Pid} ->
                case gen_tcp:controlling_process(CSock, Pid) of
                    ok ->
                        %ets:insert(montable, #monitem{socket=CSock, pid=Pid});
                        ok;
                    {error, Reason1} ->
                        common:logerror("Management server gen_server:controlling_process(Socket, PID : ~p) fails : ~p~n", [Pid, Reason1]),
                        case ti_sup:stop_child_monr(Pid) of
                            ok ->
                                ok;
                            {error, Reason2} ->
                                common:logerror("Management server ti_sup:stop_child_mon(PID : ~p) fails : ~p~n", [Pid, Reason2])
                        end
                end;
            {ok, Pid, _Info} ->
                case gen_tcp:controlling_process(CSock, Pid) of
                    ok ->
                        %ets:insert(montable, #monitem{socket=CSock, pid=Pid});
                        ok;
                    {error, Reason1} ->
                        common:logerror("Monitor server gen_server:controlling_process(Socket, PID : ~p) fails: ~p~n", [Pid, Reason1]),
                         case ti_sup:stop_child_mon(Pid) of
                            ok ->
                                ok;
                            {error, Reason2} ->
                                common:logerror("Monitor server ti_sup:stop_child_mon(PID : ~p) fails : ~p~n", [Pid, Reason2])
                        end
                end;
            {error, already_present} ->
                common:logerror("Monitor server ti_sup:start_child_man fails : already_present~n");
            {error, {already_started, Pid}} ->
                common:logerror("Monitor server ti_sup:start_child_man fails : already_started PID : ~p~n", [Pid]);
            {error, Msg} ->
                common:logerror("Monitor server ti_sup:start_child_man fails : ~p~n", [Msg])
        end,
        %% Signal the network driver that we are ready to accept another connection        
        case prim_inet:async_accept(LSock, -1) of           
            {ok, NewRef} -> 
                {noreply, State#serverstate{acceptor=NewRef}};
            Error ->
                common:logerror("Monitor server prim_inet:async_accept fails : ~p~n", [inet:format_error(Error)]),
                % Why use exit here?
                % {stop, Error, State}
                % Please consider it in the future
                exit({async_accept, inet:format_error(Error)})        
        end
    catch 
        exit:Why ->        
            common:logerror("Monitor server error in async accept : ~p~n", [Why]),            
            {stop, Why, State}    
    end;
%%%
%%% Data should not be received here because it is a listening socket process
%%%
handle_info({tcp, Socket, Data}, State) ->  
    common:printsocketinfo(Socket, "Monitor server receives data from"),
    common:logerror("ERROR : Monitor server receives data : ~p~n", [Data]),
    inet:setopts(Socket, [{active, once}]),
    {noreply, State}; 
handle_info({inet_async, LSock, Ref, Error}, #serverstate{lsock=LSock, acceptor=Ref}=State) ->    
    common:logerror("Monitor server error in socket acceptor : ~p~n", [Error]),
    {stop, Error, State}; 
handle_info(_Info, State) ->    
    {noreply, State}. 

terminate(Reason, State) ->    
    common:logerror("Monitor server is terminated~n", [Reason]),
    gen_tcp:close(State#serverstate.lsock),    
    ok. 

code_change(_OldVsn, State, _Extra) ->    
    {ok, State}. 
    

                                