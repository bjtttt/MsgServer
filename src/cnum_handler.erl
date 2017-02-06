-module(cnum_handler).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("header.hrl").

start_link(Socket) ->   
    gen_server:start_link(?MODULE, [Socket], []). 

init([Socket]) ->
	process_flag(trap_exit, true),
    [{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
	[{drivertablepid, DriverTablePid}] = ets:lookup(msgservertable, drivertablepid),
	[{vdrlogpid, VDRLogPid}] = ets:lookup(msgservertable, vdrlogpid),
	[{vdronlinepid, VDROnlinePid}] = ets:lookup(msgservertable, vdronlinepid),
    case common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            State=#monitem{socket=Socket, pid=self(), addr=Address, dbpid=DBPid, driverpid=DriverTablePid, vdrlogpid=VDRLogPid, vdronlinepid=VDROnlinePid},
            ets:insert(montable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State};
        {error, _Reason} ->
            State=#monitem{socket=Socket, pid=self(), addr="0.0.0.0", dbpid=DBPid, driverpid=DriverTablePid, vdrlogpid=VDRLogPid, vdronlinepid=VDROnlinePid},
            ets:insert(montable, State), 
            inet:setopts(Socket, [{active, once}]),
            {ok, State}
    end.            

handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast(_Msg, State) ->    
    {noreply, State}. 

handle_info({tcp, Socket, Data}, State) ->    
    %common:loginfo("Data from CNUM (~p) : ~p~n", [State#monitem.addr, Data]),
    cnum_data_parser:parse_data(Data, State),
    %common:loginfo("Response to CNUM (~p) : ~p~n", [State#monitem.addr, Resp]),
    inet:setopts(Socket, [{active, once}]),
    {noreply, State}; 
handle_info({tcp_closed, _Socket}, State) ->    
    common:loginfo("Cnum ~p is disconnected and CNUM PID ~p stops~n", [State#monitem.addr, State#monitem.pid]),
    {stop, normal, State}; 
handle_info(_Info, State) ->    
    {noreply, State}. 

terminate(Reason, State) ->
    common:loginfo("CNUM (~p) starts being terminated~nReason : ~p~n", [State#monitem.addr, Reason]),
	ets:delete(montable, State#monitem.socket),
    try
		gen_tcp:close(State#monitem.socket)
	catch
		_:Ex ->
			common:loginfo("CNUM (~p) : exception when gen_tcp:close : ~p~n", [State#monitem.addr, Ex])
	end,
    common:loginfo("CNUM (~p) is terminated~n", [State#monitem.addr]).

code_change(_OldVsn, State, _Extra) ->    
    {ok, State}.




