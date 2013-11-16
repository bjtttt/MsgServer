%%%
%%% Need considering how management server sends message to VDR
%%%

-module(vdr_server).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, 
         handle_info/2, terminate/2, code_change/3]). 

%-export([terminate_invalid_vdrs/1]).

-include("header.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% In fact, we can get PortVDR from msgservertable.
% Here, the reason that we use parameter is for efficiency.
%
% Result = {ok,Pid} | ignore | {error,Error}
%    Pid = pid()
%  Error = {already_started,Pid} | term()
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_link(PortVDR) ->  
	case gen_server:start_link({local, ?MODULE}, ?MODULE, [PortVDR], []) of
        {ok, Pid} ->
            {ok, Pid};
        ignore ->
            common:logerror("vdr_server:start_link(~p) fails : ignore", [PortVDR]),
            ignore;
        {already_started, Pid} ->
            common:logerror("vdr_server:start_link(~p) fails : already_started : ~p", [PortVDR, Pid]),
            {already_started, Pid}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% {backlog, 30} specifies the length of the OS accept queue. 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init([PortVDR]) ->    
	process_flag(trap_exit, true),    
	Opts = [binary, {packet, 0}, {reuseaddr, true}, {keepalive, true}, {active, once}],    
	% VDR server start listening
    case gen_tcp:listen(PortVDR, Opts) of	    
		{ok, LSock} -> 
            common:logerror("vdr_server:init([~p]) : gen_tcp:listen ok", [PortVDR]),
            % Create first accepting process	        
			case prim_inet:async_accept(LSock, -1) of
                {ok, Ref} ->
                    %common:loginfo("vdr_server:init([~p]) : prim_inet:async_accept accept ok", [PortVDR]),
                    {ok, #serverstate{lsock=LSock, acceptor=Ref}};
                Error ->
                    common:logerr("vdr_server:init([~p]) : prim_inet:async_accept accept fails : ~p", [PortVDR, Error]),
                    {stop, Error}
            end;
		{error, Reason} ->	        
            common:logerror("vdr_server:init([~p]) : gen_tcp:listen fails : ~p", [PortVDR, Reason]),
			{stop, Reason}    
	end. 

handle_call(Request, _From, State) ->    
	{stop, {unknown_call, Request}, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

handle_info({inet_async, LSock, Ref, {ok, CSock}}, #serverstate{lsock=LSock, acceptor=Ref}=OriState) ->
    [{linkpid, LinkPid}] = ets:lookup(msgservertable, linkpid),
	State = OriState#serverstate{linkpid=LinkPid},
    %common:printsocketinfo(CSock, "Accepted one VDR"),
    try        
		case common:set_sockopt(LSock, CSock, "vdr_server:handle_info(...)") of	        
			ok -> 
				ok;	        
			{error, Reason} -> 
                common:logerror("vdr_server:handle_info(...) : common:set_sockopt(...) fails : ~p", [Reason]),
  				% Why use exit here?
                % {stop, set_sockpt, Reason}
                % Please consider it in the future
                exit({set_sockopt, Reason})       
		end,
		% New client connected
        % Spawn a new process using the simple_one_for_one supervisor.
        % Why it is "the simple_one_for_one supervisor"?
        case common:safepeername(CSock) of
            {ok, {Addr, _Port}} ->
                case mssup:start_child_vdr(CSock, Addr) of
                    {ok, Pid} ->
                        case gen_tcp:controlling_process(CSock, Pid) of
                            ok ->
                                ok;
                            {error, Reason1} ->
                                common:logerror("vdr_server:handle_info(...) : gen_server:controlling_process(Socket, ~p) fails : ~p", [Pid, Reason1]),
                                case mssup:stop_child_vdr(Pid) of
                                    ok ->
                                        ok;
                                    {error, Reason2} ->
                                        common:logerror("vdr_server:handle_info(...) : mssup:stop_child_vdr(~p) fails : ~p", [Pid, Reason2])
                                end
                        end;
                    {ok, Pid, _Info} ->
                        case gen_tcp:controlling_process(ç, Pid) of
                            ok ->
                                ok;
                            {error, Reason1} ->
                                common:logerror("vdr_server:handle_info(...) : gen_server:controlling_process(Socket, ~p) fails: ~p", [Pid, Reason1]),
                                case mssup:stop_child_vdr(Pid) of
                                    ok ->
                                        ok;
                                    {error, Reason2} ->
                                        common:logerror("vdr_server:handle_info(...) : mssup:stop_child_vdr(~p) fails : ~p", [Pid, Reason2])
                                end
                        end;
                    {error, already_present} ->
                        common:logerror("vdr_server:handle_info(...) : mssup:start_child_vdr fails : already_present");
                    {error, {already_started, Pid}} ->
                        common:logerror("vdr_server:handle_info(...) : mssup:start_child_vdr fails : already_started PID : ~p", [Pid]);
                    {error, Msg} ->
                        common:logerror("vdr_server:handle_info(...) : mssup:start_child_vdr fails : ~p", [Msg])
                end;
            {error, Err} ->
                common:logerror("vdr_server:handle_info(...) : cannot start new process for new connection because common:safepeername(...) fails : ~p", [Err])
        end,
        %% Signal the network driver that we are ready to accept another connection        
		case prim_inet:async_accept(LSock, -1) of	        
			{ok, NewRef} -> 
                {noreply, State#serverstate{acceptor=NewRef}};
			Error ->
                common:logerror("vdr_server:handle_info(...) : prim_inet:async_accept fails : ~p", [inet:format_error(Error)]),
                % Why use exit here?
                % {stop, Error, State}
                % Please consider it in the future
                exit({async_accept, inet:format_error(Error)})        
		end
	catch 
		exit:Why ->    
			[ST] = erlang:get_stacktrace(),
            common:logerror("vdr_server:handle_info(...) : inet_async exception : ~p~nStack trace :~n~p", [Why, ST]),			
            {stop, Why, State}    
	end;
%%%
%%% Data should not be received here because it is a listening socket process
%%%
handle_info({tcp, Socket, _Data}, State) ->  
	common:send_stat_err_server(State, servermsg),
	inet:setopts(Socket, [{active, once}]),
    {noreply, State}; 
handle_info({inet_async, LSock, Ref, Error}, #serverstate{lsock=LSock, acceptor=Ref}=OriState) ->    
    [{linkpid, LinkPid}] = ets:lookup(msgservertable, linkpid),
	State = OriState#serverstate{linkpid=LinkPid},
	{stop, Error, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

terminate(Reason, State) ->    
    common:logerror("vdr_server:terminate(...) : ~p", [Reason]),
	gen_tcp:close(State#serverstate.lsock),    
	ok. 

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}. 
    
								