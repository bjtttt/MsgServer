%%%
%%% This is the DB client. However, it use gen_server.
%%%

-module(ti_client_db).

-behaviour(gen_server).

-include("ti_header.hrl").

-export([start_link/3]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

% Need consideration here
-record(state, {lsock, db, dbport, dbsock}).

start_link(DB, Port, LSock) ->
    gen_server:start_link(?MODULE, [DB, Port, LSock], []).

init([DB, Port, LSock]) ->
	{ok, #state{lsock=LSock, db=DB, dbport=Port, dbsock=undefined}, 0}.

handle_call(Msg, _From, State) ->
    {reply, {ok, Msg}, State}.

handle_cast(stop, State) ->
    {stop, normal, State}.

handle_info({tcp, Socket, RawData}, State) ->
    NewState = handle_data(Socket, RawData, State),
    {noreply, NewState};
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
handle_info(timeout, State) ->
    error_logger:info_msg("~p : Try to connect DB (~p:~p) ... ", 
						  [calendar:now_to_local_time(erlang:now()), State#state.db, State#state.dbport]),
	case gen_tcp:connect(State#state.db, State#state.dbport, [{active, true}]) of
		{ok, CSock} ->
			error_logger:info_msg("~p : Connected.~n", 
								  [calendar:now_to_local_time(erlang:now())]),
			Pid = spawn(fun() -> db_message_processor(CSock) end),
			ets:insert(msgservertable, {dbconnpid, Pid}),
			ti_sup_db:start_child(),
			{noreply, State#state{dbsock=CSock}};
		{error, Reason} ->
			error_logger:error_msg("~p : Fails : ~p.~n", 
								   [calendar:now_to_local_time(erlang:now()), Reason]),
			[{dbconnpid, Pid}] = ets:lookup(msgservertable, dbconnpid),
			case Pid of
				-1 ->
					ok;
				_ ->
					ets:insert(msgservertable, {dbconnpid, -1})
			end,
			ti_sup_db:start_child(),
			{stop, error, State}
	end.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Internal functions
handle_data(Socket, RawData, State) ->
	Socket,
	RawData,
    State.

%%%
%%% VDR process will send message to this process. 
%%% This process will translate the message and send the new message to the database.
%%% At the same time, it will check whether the message from VDR should also be sent to the manage server or not.
%%% If so, this process will send the message to the process which is responsible for the talk to the management server.
%%%
%%% Socket : connection between DB
%%%
db_message_processor(Socket) ->
	receive
		{From, Msg} ->
			% Communicate with DB here
			From,
			do_process_message(Socket, Msg),
			db_message_processor(Socket);
		stop ->
			true
	end.

do_process_message(Socket, Msg) ->
	Socket,
	Msg.

