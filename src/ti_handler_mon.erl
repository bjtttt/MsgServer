-module(ti_handler_mon).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

start_link(Socket) ->   
    gen_server:start_link(?MODULE, [Socket], []). 

init([Socket]) ->
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            State=#monitem{socket=Socket, pid=self(), addr=Address},
            ets:insert(montable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State};
        {error, _Reason} ->
            State=#monitem{socket=Socket, pid=self(), addr="0.0.0.0"},
            ets:insert(montable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State}
    end.            

handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->    
    {noreply, State}. 

handle_info({tcp, Socket, Data}, State) ->    
    case ti_mon_data_parser:parse_data(Socket, Data) of
        {ok, Decoded} ->
            process_mon_data(Socket, Decoded);
        _ ->
            ok
    end,
    inet:setopts(Socket, [{active, once}]),
    % Should be modified in the future
    %ok = gen_tcp:send(Socket, <<"Monitor : ", Resp/binary>>),    
    {noreply, State}; 
handle_info({tcp_closed, _Socket}, State) ->    
    ti_common:loginfo("Monitor ~p is disconnected and monitor PID ~p stops~n", [State#monitem.addr, State#monitem.pid]),
    {stop, normal, State}; 
handle_info(_Info, State) ->    
    {noreply, State}. 

terminate(Reason, #monitem{socket=Socket}) ->    
    (catch gen_tcp:close(Socket)),    
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo("Monitor ~p socket is closed and monitor PID ~p is terminated : ~p~n", [Address, self(), Reason]);
        {error, _Reason} ->
            ti_common:loginfo("Monitor socket is closed and monitor PID ~p is terminated : ~p~n", [self(), Reason])
    end.

code_change(_OldVsn, State, _Extra) ->    
    {ok, State}.

%%%
%%% This function should refer to the document on the mechanism
%%%
process_mon_data(Socket, Data) ->
    Bin = ti_mon_data_parser:parse_data(Data),
    gen_tcp:send(Socket, Bin).





