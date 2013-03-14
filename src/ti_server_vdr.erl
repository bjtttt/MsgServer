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

%%%
%%% {backlog, 30} specifies the length of the OS accept queue. 
%%%
init([PortVDR]) ->    
	process_flag(trap_exit, true),    
	Opts = [binary, {packet, 0}, {reuseaddr, true}, {keepalive, true}, {active, once}],    
	% VDR server start listening
    case gen_tcp:listen(PortVDR, Opts) of	    
		{ok, LSock} -> 
            % Create first accepting process	        
			case prim_inet:async_accept(LSock, -1) of
                {ok, Ref} ->
                    {ok, #state{lsock = LSock, acceptor = Ref}};
                Error ->
                    ti_common:logerror("VDR server async accept fails : ~p~n", Error),
                    {stop, Error}
            end;
		{error, Reason} ->	        
            ti_common:logerror("VDR server listen fails : ~p~n", Reason),
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
                ti_common:logerror("VDR server set_sockopt fails when inet_async : ~p~n", Reason),
  				exit({set_sockopt, Reason})       
		end,
		% New client connected
        % Spawn a new process using the simple_one_for_one supervisor.
        % Why it is "the simple_one_for_one supervisor"?
        case ti_sup:start_child_vdr(CSock) of
            {ok, Pid} ->
                case gen_tcp:controlling_process(CSock, Pid) of
                   ok ->
                        ok;
                    {error, Reason1} ->
                        ti_common:logerror("VDR server gen_server:controlling_process fails when inet_async : ~p~n", Reason1)
                end;
            {ok, Pid, _Info} ->
                case gen_tcp:controlling_process(CSock, Pid) of
                   ok ->
                        ok;
                    {error, Reason1} ->
                        ti_common:logerror("VDR server gen_server:controlling_process fails when inet_async : ~p~n", Reason1)
                end;
            {error, already_present} ->
                ti_common:logerror("VDR server ti_sup:start_child_vdr fails when inet_async : already_present~n");
            {error, {already_started, Pid}} ->
                ti_common:logerror("VDR server ti_sup:start_child_vdr fails when inet_async : already_started PID : ~p~n", Pid);
            {error, Msg} ->
                ti_common:logerror("VDR server ti_sup:start_child_vdr fails when inet_async : ~p~n", Msg)
        end,
		% {ok, Pid} = ti_app:start_client_vdr(CSock),        
	    %Pid = spawn(fun() -> loop(CSock) end),
        %gen_tcp:controlling_process(CSock, Pid),
        %loop(CSock),
        %case gen_server:start_link(ti_handler_vdr, [CSock], []) of
        %    {ok, Pid}  ->
        %        case gen_tcp:controlling_process(CSock, Pid) of
        %           ok ->
        %                ok;
        %            {error, Reason1} ->
        %                ti_common:logerror("VDR server gen_server:controlling_process fails when inet_async : ~p~n", Reason1)
        %        end;
        %    {error, Reason2} ->
        %        ti_common:logerror("VDR server gen_server:start_link(ti_handler_vdr,...) fails when inet_async : ~p~n", Reason2);
        %    ignore ->
        %        ti_common:logerror("VDR server gen_server:start_link(ti_handler_vdr,...) fails when inet_async : ignore~n")
        %end,
        %% Signal the network driver that we are ready to accept another connection        
		case prim_inet:async_accept(LSock, -1) of	        
			{ok, NewRef} -> 
                {noreply, State#state{acceptor=NewRef}};
			Error ->
                ti_common:logerror("VDR server prim_inet:async_accept fails when inet_async : ~p~n", inet:format_error(Error)),
                {stop, Error, State}
                %exit({async_accept, inet:format_error(Error)})        
		end
	catch 
		exit:Why ->        
            ti_common:logerror("VDR server error in async accept : ~p~n", Why),			
            {stop, Why, State}    
	end;
handle_info({tcp, Socket, Data}, State) ->    
    inet:setopts(Socket, [{active, once}]),
    % Should be modified in the future
    ok = gen_tcp:send(Socket, <<"VDR server : ", Data/binary>>),    
    {noreply, State}; 
handle_info({inet_async, LSock, Ref, Error}, #state{lsock=LSock, acceptor=Ref} = State) ->    
    ti_common:logerror("VDR server error in socket acceptor : ~p~n", Error),
	{stop, Error, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

terminate(Reason, State) ->    
    ti_common:logerror("VDR server is terminated~n", Reason),
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
				ok -> 
					ok;		        
				Error -> 
					ti_common:logerror("VDR server prim_inet:setopts fails : ~p~n", Error),    
                    gen_tcp:close(CSock)
			end;	   
		Error ->	       
            ti_common:logerror("VDR server prim_inet:getopts fails : ~p~n", Error),
			gen_tcp:close(CSock)
	end.

%%%
%%% Test only
%%%
%loop(Socket) ->
%    receive
%        {tcp, Socket, Bin} ->
%            %inet:setopts(Socket, [{active, true}]),
%            io:format("Server received binary = ~p~n", [Bin]),
%            gen_tcp:send(Socket, Bin),
%            loop(Socket);
%        {tcp_closed, Socket} ->
%            io:format("Server socket closed~n");
%        Msg ->
%            Msg
%    end.


								