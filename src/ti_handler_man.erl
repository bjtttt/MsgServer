-module(ti_handler_man).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

start_link(Socket) ->   
    gen_server:start_link(?MODULE, [Socket], []). 

init([Socket]) ->
    Pid = spawn(fun() -> send_data_to_management_process(Socket) end),
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            State=#manitem{socket=Socket, pid=self(), datapid=Pid, addr=Address},
            ets:insert(mantable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State};
        {error, _Reason} ->
            State=#manitem{socket=Socket, pid=self(), datapid=Pid, addr="0.0.0.0"},
            ets:insert(mantable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State}
    end.            

handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->    
    {noreply, State}. 

handle_info({tcp, Socket, Data}, State) ->    
    case ti_man_data_parser:parse_data(Socket, Data) of
        {ok, Decoded} ->
            process_man_data(Socket, Decoded);
        _ ->
            ok
    end,
    inet:setopts(Socket, [{active, once}]),
    % Should be modified in the future
    %ok = gen_tcp:send(Socket, <<"Management : ", Resp/binary>>),    
    {noreply, State}; 
handle_info({tcp_closed, _Socket}, State) ->    
    ti_common:loginfo("Management ~p is disconnected, management PID ~p stops and management data PID ~p stops~n", [State#manitem.addr, State#manitem.pid, State#manitem.datapid]),
    State#manitem.datapid!stop,
    {stop, normal, State}; 
handle_info(_Info, State) ->    
    {noreply, State}. 

terminate(Reason, State) ->
    State#manitem.datapid!stop,
    (catch gen_tcp:close(State#vdritem.socket)),    
    ti_common:loginfo("Management PID ~p is terminated, management data PID ~p stops and management ~p socket is closed : ~p~n", [State#manitem.pid, State#manitem.datapid, State#manitem.addr, Reason]).

code_change(_OldVsn, State, _Extra) ->    
    {ok, State}.

%%%
%%% This function should refer to the document on the mechanism
%%%
process_man_data(Socket, Data) ->
    Socket,
    Bin = ti_man_data_parser:parse_data(Data),
    Bin.

send_data_to_management_process(Socket) ->
    receive
        {_FromPid, {data, Data}} ->
            gen_tcp:send(Socket, Data),
            send_data_to_management_process(Socket);
        {FromPid, Data} ->
            ti_common:logerror("Management server send data to management process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            send_data_to_management_process(Socket);
        stop ->
            true
    after ?TIMEOUT_DATA_VDR ->
        %ti_common:loginfo("Management server send data to management process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
        send_data_to_management_process(Socket)
    end.
