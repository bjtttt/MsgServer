-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

start_link(Socket, Addr) ->	
	gen_server:start_link(?MODULE, [Socket, Addr], []). 

init([Socket, Addr]) ->
    %process_flag(trap_exit, true),
    VDRPid = spawn(fun() -> data2vdr_process(Socket) end),
    Pid = self(),
    State=#vdritem{socket=Socket, pid=Pid, vdrpid=VDRPid, addr=Addr},
    ets:insert(vdrtable, State), 
    inet:setopts(Socket, [{active, once}]),
	{ok, State}.

handle_call(_Request, _From, State) ->
	{noreply, ok, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

%%%
%%% VDR handler receives date from VDR
%%% Steps :
%%%     1. Parse the data
%%%     2. Check whether it is ID reporting message
%%%         YES -> 
%%%             Update the vdritem record
%%%         NO ->
%%%             A. Check whether the VDR has reported ID or not
%%%                 YES ->
%%%                     a. Send it to the DB
%%%                     b. Check whether it is a management reporting message
%%%                         YES ->
%%%                             Report the data to the management platform
%%%                         NO ->
%%%                             Do nothing
%%%                 NO ->
%%%                     a. Discard the data
%%%                     b. Request ID reporting message (REALLY NEEDED?)
%%%
handle_info({tcp, Socket, Data}, State) ->    
    case ti_vdr_data_parser:process_data(Socket, State, Data) of
        {ok, Decoded, NewState} ->
            process_vdr_data(Socket, Decoded),
            inet:setopts(Socket, [{active, once}]),
            {noreply, NewState};
        {fail, _ResendList} ->
            inet:setopts(Socket, [{active, once}]),
            {noreply, State};
        error ->
            inet:setopts(Socket, [{active, once}]),
            {noreply, State}
    end;
handle_info({tcp_closed, _Socket}, State) ->    
    ti_common:loginfo("VDR (~p) TCP is closed~n"),
    % return stop will invoke terminate(Reason,State)
    % tcp_closed will be transfered as Reason
	{stop, tcp_closed, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

%%%
%%% When VDR handler process is terminated, do the clean jobs here
%%%
terminate(Reason, State) ->
    VDRPid = State#vdritem.vdrpid,
    case VDRPid of
        undefined ->
            ok;
        _ ->
            VDRPid!stop
    end,
	try gen_tcp:close(State#vdritem.socket) of
        ok ->
            ok
    catch
        _:Exception ->
            ti_common:logerror("Exception when closing VDR (~p) TCP : ~p~n", [State#vdritem.addr, Exception])
    end,
    ti_common:loginfo("VDR handler process (~p) is terminated : ~p~n", [State#vdritem.pid, Reason]).


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

%%%
%%% This process is send msg from the management to the VDR.
%%% Each time when sending msg from the management to the VDR, a flag should be set in vdritem.
%%% If the ack from the VDR is received in handle_info({tcp,Socket,Data},State), this flag will be cleared.
%%% After the defined TIMEOUT is achived, it means VDR cannot response and the TIMEOUT should be adjusted and this msg will be sent again.
%%% (Please refer to the specification for this mechanism.)
%%%
data2vdr_process(Socket) ->
    receive
        {_FromPid, {data, Data}} ->
            gen_tcp:send(Socket, Data),
            data2vdr_process(Socket);
        {FromPid, Data} ->
            ti_common:logerror("VDR server send data to VDR process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            data2vdr_process(Socket);
        stop ->
            ok
    after ?TIMEOUT_DATA_VDR ->
        %ti_common:loginfo("VDR server send data to VDR process process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
        data2vdr_process(Socket)
    end.
