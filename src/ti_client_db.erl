-module(ti_client_db).

-behaviour(gen_server).

-include("ti_common.hrl").

-export([start_link/3]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

% Need consideration here
-record(state, {lsock, db, dbport, dbsock, dbpid, dbmsgpid}).

start_link(DB, Port, LSock) ->
    gen_server:start_link(?MODULE, [DB, Port, LSock], []).

init([DB, Port, LSock]) ->
	{ok, #state{lsock=LSock, db=DB, dbport=Port, dbsock=undefined, dbpid=self(), dbmsgpid=undefined}, 0}.

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
	case gen_tcp:connect(State#state.db, State#state.dbport, [{active, true}]) of
		{ok, CSock} ->
			ets:insert(serverstatetable, {dbconncount,0}),
			Pid = spawn(fun() -> db_message_processor(CSock) end),
			ets:insert(serverstatetable,{dbconnpid,Pid}),
			{noreply, State#state{dbsock=CSock,dbmsgpid=Pid}};
		{error, Reason} ->
			error_logger:error_msg("Cannot connect DB (~p:~p) : ~p~nTry again.~n", [State#state.db, State#state.dbport, Reason]),
			ti_sup_db:start_link(State#state.db, State#state.dbport),
			{noreply, State}
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

