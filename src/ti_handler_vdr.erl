-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

start_link(Socket) ->	
	gen_server:start_link(?MODULE, [Socket], []). 

init([Socket]) ->
    Pid = spawn(fun() -> send_data_to_vdr_process(Socket) end),
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            State=#vdritem{socket=Socket, pid=self(), datapid=Pid, addr=Address},
            ets:insert(vdrtable, State), 
            inet:setopts(Socket, [{active, once}]),
        	{ok, State};
        {error, _Reason} ->
            State=#vdritem{socket=Socket, pid=self(), datapid=Pid, addr="0.0.0.0"},
            ets:insert(vdrtable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State}
    end.            

handle_call(_Request, _From, State) ->
	{noreply, ok, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

handle_info({tcp, Socket, Data}, State) ->    
    case ti_vdr_data_parser:parse_data(Socket, Data) of
        {ok, Decoded} ->
            process_vdr_data(Socket, Decoded);
        _ ->
            ok
    end,
	inet:setopts(Socket, [{active, once}]),
    % Should be modified in the future
	%ok = gen_tcp:send(Socket, <<"VDR : ", Resp/binary>>),    
	{noreply, State}; 
handle_info({tcp_closed, _Socket}, State) ->    
    ti_common:loginfo("VDR ~p is disconnected, VDR PID ~p stops and VDR data PID ~p stops~n", [State#vdritem.addr, State#vdritem.pid, State#vdritem.datapid]),
    State#vdritem.datapid!stop,
	{stop, normal, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

terminate(Reason, State) ->
    State#vdritem.datapid!stop,
	(catch gen_tcp:close(State#vdritem.socket)),    
    ti_common:loginfo("VDR PID ~p is terminated, VDR data PID ~p stops and VDR ~p socket is closed : ~p~n", [State#vdritem.pid, State#vdritem.datapid, State#vdritem.addr, Reason]).

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}.

%%%
%%% This function should refer to the document on the mechanism
%%%
process_vdr_data(Socket, Data) ->
    Bin = ti_vdr_data_parser:parse_data(Data),
    [{dbconnpid, Pid}] = ets:lookup(msgservertable, dbconnpid),
    case Pid of
        -1 ->
            ti_common:logerror("DB Client is not available~n");
        _ ->
            Pid!Bin,
            receive
                {From, Resp} ->
                    if
                        From == Pid ->
                            Back = ti_vdr_data_parser:compose_data(Resp),
                            gen_tcp:send(Socket, Back);
                        From =/= Pid ->
                            ti_common:logerror("Unknown VDR response from ~p~n", From)
                    end;
                _ ->
                    ti_common:logerror("Unknown VDR response from DB~n")
            end
    end.

send_data_to_vdr_process(Socket) ->
    receive
        {_FromPid, {data, Data}} ->
            gen_tcp:send(Socket, Data),
            send_data_to_vdr_process(Socket);
        {FromPid, Data} ->
            ti_common:logerror("VDR server send data to VDR process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            send_data_to_vdr_process(Socket);
        stop ->
            true
    after ?TIMEOUT_DATA_VDR ->
        %ti_common:loginfo("VDR server send data to VDR process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
        send_data_to_vdr_process(Socket)
    end.
