-module(ti_handler_vdr).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2, code_change/3]).

-include("ti_header.hrl").

-define(TIMEOUT, 120000). 

start_link(Socket) ->	
	gen_server:start_link(?MODULE, [Socket], []). 

init([Socket]) ->	
    inet:setopts(Socket, [{active, once}]), 
	{ok, #vdritem{socket=Socket}}. 

handle_call(_Request, _From, State) ->
	{noreply, ok, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

handle_info({tcp, Socket, Data}, State) ->    
	inet:setopts(Socket, [{active, once}]),
    case ti_vdr_data_parser:parse_data(Socket, Data) of
        {ok, Decoded} ->
            process_vdr_data(Socket, Decoded);
        _ ->
            ok
    end,
    % Should be modified in the future
	%ok = gen_tcp:send(Socket, <<"VDR : ", Resp/binary>>),    
	{noreply, State}; 
handle_info({tcp_closed, Socket}, State) ->    
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo("VDR IP : ~p~n", Address);
        {error, Explain} ->
            ti_common:loginfo("Unknown VDR : ~p~n", Explain)
    end,
    ti_common:loginfo("VDR is disconnected~n"),
    ti_common:loginfo("VDR Pid ~p stops~n", self()),
	{stop, normal, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

terminate(_Reason, #state{socket=Socket}) ->    
    ti_common:loginfo("VDR Pid ~p is terminated~n", self()),
	(catch gen_tcp:close(Socket)),    
	ok.

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


