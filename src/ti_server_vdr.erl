%%%
%%% Need considering how management server sends message to VDR
%%%

-module(ti_server_vdr).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {lsock}).

start_link(LSock) ->
    gen_server:start_link(?MODULE, [LSock], []).

init([LSock]) ->
    {ok, #state{lsock = LSock}, 0}.

handle_call(Msg, _From, State) ->
    {reply, {ok, Msg}, State}.

handle_cast(stop, State) ->
    {stop, normal, State}.

handle_info({tcp, Socket, RawData}, State) ->
    NewState = handle_data(Socket, RawData, State),
    {noreply, NewState};
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
handle_info(timeout, #state{lsock = LSock} = State) ->
    case gen_tcp:accept(LSock) of
		{ok, ASock} ->
			case ti_common:safepeername(ASock) of
				{ok, {Address, Port}} ->
            		error_logger:info_msg("~p : VDR connection from ~p:~p~n", [calendar:now_to_local_time(erlang:now()), Address, Port]),
					ok;
				{error, Msg} ->
            		error_logger:info_msg("~p : unknown VDR connection : ~p~n", [calendar:now_to_local_time(erlang:now()), Msg]),
					ok
			end,
			% -1 means this VDR hasn't report its ID yet.
			ets:insert(vdrinittable, {ASock, -1, calendar:now_to_local_time(erlang:now())});
		{error, Reason} ->
       		error_logger:error_msg("~p : accepting VDR error : ~p~n", [calendar:now_to_local_time(erlang:now()), Reason])
	end,
    ti_sup:start_child(),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%
%% Process data from VDR.
%%     1. parse data
%%     2. send message to DB client process
%%     3. check whether message should be sent to management server
%%
handle_data(Socket, RawData, State) ->
	Socket,
	ti_vdr_data_parser:parse_data(RawData),
    State.



