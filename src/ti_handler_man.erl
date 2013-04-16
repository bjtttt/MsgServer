-module(ti_handler_man).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

start_link(Socket, Addr) ->   
    gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Socket, Addr]) ->
    Pid = self(),
    ManPid = spawn(fun() -> data2man_process(Socket) end),
    State=#manitem{socket=Socket, pid=Pid, manpid=ManPid, addr=Addr},
    ets:insert(mantable, State), 
    inet:setopts(Socket, [{active, once}]),
    {ok, State}.

handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->    
    {noreply, State}. 

handle_info({tcp, Socket, Data}, State) ->    
    case process_man_data(Socket, Data,State) of
        {error, NewState} ->
             {stop, NewState};
        _ ->
            inet:setopts(Socket, [{active, once}]),
            % Should be modified in the future
            %ok = gen_tcp:send(Socket, <<"Management : ", Resp/binary>>),    
            {noreply, State}
    end;
handle_info({tcp_closed, _Socket}, State) ->    
    ti_common:loginfo("Management (~p) : TCP is closed~n", [State#manitem.addr]),
    %State#manitem.datapid!stop,
    {stop, tcp_closed, State}; 
handle_info(_Info, State) ->    
    {noreply, State}. 

terminate(Reason, State) ->
    ManPid = State#manitem.manpid,
    case ManPid of
        undefined ->
            ok;
        _ ->
            ManPid!stop
    end,
    try gen_tcp:close(State#manitem.socket)
    catch
        _:Ex ->
            ti_common:logerror("Management (~p) : Exception when closing TCP : ~p~n", [State#manitem.addr, Ex])
    end,
    ti_common:loginfo("Management (~p) : Management handler process (~p) is terminated : ~p~n", [State#manitem.addr, State#manitem.pid, Reason]).

code_change(_OldVsn, State, _Extra) ->    
    {ok, State}.

%%%
%%% This function should refer to the document on the mechanism
%%% Maybe State is useless
%%%
process_man_data(Socket, Data, State) ->
    Socket,
    ti_man_data_parser:process_data(Data).

data2man_process(Socket) ->
    receive
        {_FromPid, {data, Data}} ->
            gen_tcp:send(Socket, Data),
            data2man_process(Socket);
        {FromPid, Data} ->
            ti_common:logerror("Management server send data to management process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            data2man_process(Socket);
        stop ->
            ti_common:logerror("Management server send data to management process stops~n"),
            true
    %after ?TIMEOUT_DATA_VDR ->
    %    %ti_common:loginfo("Management server send data to management process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
    %    send_data_to_management_process(Socket)
    end.










