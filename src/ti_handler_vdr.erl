-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-record(state, {socket, addr}).

-define(TIMEOUT, 120000). 

start_link(Socket) ->	
	gen_server:start_link(?MODULE, [Socket], []). 

init([Socket]) ->	
    inet:setopts(Socket, [{active, once}]), 
	%inet:setopts(Socket, [{active, true}, {packet, 0}, binary]),   
	{ok, {IP, _Port}} = inet:peername(Socket),
	{ok, #state{socket=Socket, addr=IP}}. 

handle_call(_Request, _From, State) ->
	{noreply, ok, State}. 
handle_cast(_Msg, State) ->    
	{noreply, State}. 
handle_info({tcp, Socket, Data}, State) ->    
	inet:setopts(Socket, [{active, once}]),	
	io:format("~p got message ~p\n", [self(), Data]),    
	ok = gen_tcp:send(Socket, <<"Echo back : ", Data/binary>>),    
	{noreply, State}; 
handle_info({tcp_closed, _Socket}, #state{addr=Addr} = StateData) ->    
	error_logger:info_msg("~p Client ~p disconnected.\n", [self(), Addr]),    
	{stop, normal, StateData}; 
handle_info(_Info, StateData) ->    
	{noreply, StateData}. 

terminate(_Reason, #state{socket=Socket}) ->    
	(catch gen_tcp:close(Socket)),    
	ok.

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}.


