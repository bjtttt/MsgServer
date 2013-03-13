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
	Opts = [binary, {packet, 2}, {reuseaddr, true}, {keepalive, true}, {backlog, 30}, {active, true}],    
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
                Format = "~p : ti_server_vdr:handler_info - set_sockopt(LSock, CSock) fails : ~p~n",
                error_logger:error_msg(Format, [TimeStamp, Reason]),
				exit({set_sockopt, Reason})       
		end,
        
		% New client connected
        % Spawn a new process using the simple_one_for_one supervisor.
        % Why it is "the simple_one_for_one supervisor"?
		%{ok, Pid} = ti_app:start_client_vdr(CSock),        
		case gen_server:start_link(ti_handler_vdr, [CSock], []) of
            {ok, Pid}  ->
                case gen_tcp:controlling_process(CSock, Pid) of
                    ok ->
                        ok;
                    {error, EReason} ->
                        RTimeStamp = calendar:now_to_local_time(erlang:now()),
                        RFormat = "~p : gen_tcp:controlling_process(CSock, Pid) fails : ~p~n",
                        error_logger:error_msg(RFormat, [RTimeStamp, EReason])
                end;
            {error, EError} ->
                ETimeStamp = calendar:now_to_local_time(erlang:now()),
                EFormat = "~p : gen_server:start_link(ti_handler_vdr, [CSock], []) fails : ~p~n",
                error_logger:error_msg(EFormat, [ETimeStamp, EError]);
            ignore ->
                ITimeStamp = calendar:now_to_local_time(erlang:now()),
                IFormat = "~p : gen_server:start_link(ti_handler_vdr, [CSock], []) fails : ignore~n",
                error_logger:error_msg(IFormat, [ITimeStamp])
        end,
        %% Signal the network driver that we are ready to accept another connection        
		case prim_inet:async_accept(LSock, -1) of	        
			{ok, NewRef} -> 
                {noreply, State#state{acceptor=NewRef}};
			Error ->
                EFormat2 = "~p : ti_server_vdr:handle_info - prim_inet:async_accept(LSock, -1) fails : ~p~n",
                ETimeStamp2 = calendar:now_to_local_time(erlang:now()),
                error_logger:error_msg(EFormat2, [ETimeStamp2, inet:format_error(Error)]),
                exit({async_accept, inet:format_error(Error)})        
		end
	catch 
		exit:Why ->        
            FFormat = "~p : Error in async accept : ~p~n",
            FTimeStamp = calendar:now_to_local_time(erlang:now()),
			error_logger:error_msg(FFormat, [FTimeStamp, Why]),        
			{stop, Why, State}    
	end; 
handle_info({tcp, Socket, Data}, State) ->    
    gen_tcp:send(Socket, "aaaaa"),
    inet:setopts(Socket, [{active, true}]), 
    io:format("~p got message ~p\n", [self(), Data]),    
    ok = gen_tcp:send(Socket, <<"Echo back : ", Data/binary>>),    
    {noreply, State}; 
handle_info({inet_async, LSock, Ref, Error}, #state{lsock=LSock, acceptor=Ref} = State) ->    
    FFormat = "~p : Error in socket acceptor : ~p~n",
    FTimeStamp = calendar:now_to_local_time(erlang:now()),
    error_logger:error_msg(FFormat, [FTimeStamp, Error]),        
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



								