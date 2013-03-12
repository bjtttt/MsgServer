%%%
%%% Need considering how management server sends message to VDR
%%%

-module(ti_server_vdr).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, 
         handle_info/2, terminate/2, code_change/3]). 

%%%
%%% lsock       : Listening socket
%%% acceptor    : Asynchronous acceptor's internal reference
%%%
-record(state, {lsock, acceptor}). 

%%%
%%% In fact, we can get PortVDR from msgservertable.
%%% Here, the reason that we use parameter is for efficiency.
%%%
start_link(PortVDR) ->    
	gen_server:start_link({local, ?MODULE}, ?MODULE, [PortVDR], []). 

init([PortVDR]) ->    
	process_flag(trap_exit, true),    
	Opts = [binary, {packet, 2}, {reuseaddr, true}, {keepalive, true}, {backlog, 30}, {active, false}],    
	case gen_tcp:listen(PortVDR, Opts) of	    
		{ok, LSock} -> 
            % Create first accepting process	        
			case prim_inet:async_accept(LSock, -1) of
                {ok, Ref} ->
                    {ok, #state{lsock = LSock, acceptor = Ref}};
                Error ->
                    TimeStamp = calendar:now_to_local_time(erlang:now()),
                    Format = "~p : VDR server async accept fails : ~p~n",
                    error_logger:error_msg(Format, [TimeStamp, Error]),
                    {stop, Error}
            end;
		{error, Reason} ->	        
			{stop, Reason}    
	end. 

handle_call(Request, _From, State) ->    
	{stop, {unknown_call, Request}, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

handle_info({inet_async, LSock, Ref, {ok, CSock}}, #state{lsock=LSock, acceptor=Ref}=State) ->    
	try        
		case set_sockopt(LSock, CSock) of	        
			ok -> 
				ok;	        
			{error, Reason} -> 
                TimeStamp = calendar:now_to_local_time(erlang:now()),
                Format = "~p : ti_server_vdr:set_sockopt(LSock, CSock) fails : ~p~n",
                error_logger:error_msg(Format, [TimeStamp, Reason]),
				exit({set_sockopt, Reason})       
		end,
		% New client connected
        % Spawn a new process using the simple_one_for_one supervisor.
		{ok, Pid} = ti_sup_vdr:start_client(CSock),        
		gen_tcp:controlling_process(CSock, Pid),         
		%% Signal the network driver that we are ready to accept another connection        
		case prim_inet:async_accept(LSock, -1) of	        
			{ok, NewRef} -> 
                {noreply, State#state{acceptor=NewRef}};
			Error -> 
                exit({async_accept, inet:format_error(Error)})        
		end
	catch 
		exit:Why ->        
			error_logger:error_msg("Error in async accept: ~p.\n", [Why]),        
			{stop, Why, State}    
	end; 
handle_info({inet_async, LSock, Ref, Error}, #state{lsock=LSock, acceptor=Ref} = State) ->    
	error_logger:error_msg("Error in socket acceptor: ~p.\n", [Error]),    
	{stop, Error, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

terminate(_Reason, State) ->    
	gen_tcp:close(State#state.lsock),    
	ok. 

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}. 

%%%
%%% Taken from prim_inet.  We are merely copying some socket options from the
%%% listening socket to the new client socket.
%%%
set_sockopt(LSock, CSock) ->    
	true = inet_db:register_socket(CSock, inet_tcp),    
	case prim_inet:getopts(LSock, [active, nodelay, keepalive, delay_send, priority, tos]) of	    
		{ok, Opts} ->	        
			case prim_inet:setopts(CSock, Opts) of		        
				ok    -> 
					ok;		        
				Error -> 
					gen_tcp:close(CSock),
                    Error	        
			end;	   
		Error ->	       
			gen_tcp:close(CSock), 
			Error   
	end.



								