-module(ti_client_db).

-behaviour(gen_server).

-include("ti_common.hrl").

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

% Need consideration here
-record(state, {db, dbport, dbsock, dbpid, dbmsgpid}).

start_link(DB, Port) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [DB, Port], []).

init([DB, Port]) ->
	{ok, #state{db=DB, dbport=Port, dbsock=undefined, dbpid=self(), dbmsgpid=undefined}, 0}.

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
	[{dbconncount,Count}] = ets:lookup(serverstatetable, dbconncount),
	if
		Count > ?DB_CONN_CNT_MAX ->
			error_logger:error_msg("Stop connecting DB (~p:~p) because of ~p continous failures.~nExit~n", [State#state.db, State#state.dbport, Count]),
			exit("DB connection error.");
		Count =< ?DB_CONN_CNT_MAX ->
			case gen_tcp:connect(State#state.db, State#state.dbport, [{active, true}]) of
				{ok, SockConn} ->
					ets:insert(serverstatetable, {dbconncount,0}),
					PidConn = spawn(fun() -> db_message_processor(SockConn) end),
					ets:insert(serverstatetable,{dbconnpid,PidConn}),
					{noreply, State#state{dbsock=SockConn,dbmsgpid=PidConn}};
				{error, Reason} ->
					ets:insert(serverstatetable, {dbconncount,Count+1}),
					error_logger:error_msg("Cannot connect DB (~p:~p) : ~p~nTry again.~n", [State#state.db, State#state.dbport, Reason]),
					ti_sup_db:start_link(State#state.db, State#state.dbport),
					{noreply, State}
			end
	end.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Internal functions
handle_data(Socket, RawData, State) ->
    try
        {Function, RawArgList} =
            lists:splitwith(fun (C) -> C =/= $[ end, RawData),
        {ok, Toks, _Line} = erl_scan:string(RawArgList ++ ".", 1),
        {ok, Args} = erl_parse:parse_term(Toks),
        Result = apply(simple_cache, list_to_atom(Function), Args),
        gen_tcp:send(Socket, io_lib:fwrite("OK:~p.~n", [Result]))
    catch
        _Class:Err ->
            gen_tcp:send(Socket, io_lib:fwrite("ERROR:~p.~n", [Err]))
    end,
    State.

db_message_processor(Socket) ->
	receive
		{From, Msg} ->
			% Communicate with DB here
			From,
			Msg,
			db_message_processor(Socket);
		stop ->
			true
	end.
