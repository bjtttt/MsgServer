%%%
%%% This is the DB client. However, it use gen_server.
%%%

-module(ti_client_db).

-behaviour(gen_server).

-include("ti_header.hrl").

-export([start_link/2]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%%
%%% In fact, we can get DB & PortDB from msgservertable.
%%% Here, the reason that we use parameter is for efficiency.
%%%
start_link(DB, PortDB) ->
    gen_server:start_link(?MODULE, [DB, PortDB], []).

%%%
%%% If a permanent application terminates, all other applications and the entire Erlang node are also terminated.
%%% If a transient application terminates with Reason == normal, this is reported but no other applications are terminated. If a transient application terminates abnormally, all other applications and the entire Erlang node are also terminated.
%%% If a temporary application terminates, this is reported but no other applications are terminated.
%%%
init([DB, PortDB]) ->
    {ok, #dbstate{db=DB, dbport=PortDB}, 0}.

handle_call(Msg, _From, State) ->
    {reply, {ok, Msg}, State}.

handle_cast(stop, State) ->
    {stop, normal, State}.

handle_info({tcp, Socket, Data}, State) ->
    ti_common:printsocketinfo(Socket, "ERROR : DB Client receives data from"),
    ti_common:logerror("ERROR : DB Client receives data : ~p~n", [Data]),
    %NewState = handle_data(Socket, Data, State),
    %{noreply, NewState};
    {noreply, State};
handle_info({tcp_closed, Socket}, State) ->
    ti_common:printsocketinfo(Socket, "DB Client receives tcp_closed from"),
    stop_db(),
    {stop, normal, State};
handle_info(timeout, State) ->
    case odbc:start(permanent) of
        ok ->
            [{dbdsn, DBDSN}] = ets:lookup(msgservertable, dbdsn),
            Connection = string:concat(string:concat("DSN=", DBDSN), "UID=aladdin;PWD=sesame"),
            case odbc:connect(Connection, []) of
                {ok, Ref} ->
                    ets:insert(msgservertable, {dbref, Ref}),
                    Pid = spawn(fun() -> db_message_processor(Ref) end),
                    ets:insert(msgservertable, {dbconnpid, Pid}),
                    {noreply, #dbstate{dbref=Ref, dbconnpid=Pid}=State};
                {error, Reason} ->
                    ti_common:logerror("ODBC cannot connect ~p : ~p~n", [Connection, Reason]),
                    {stop, error, Reason}
            end;
        {error, Reason} ->
            ti_common:logerror("ODBC cannot start : ~p~n", [Reason]),
            {stop, error, Reason}
    end.

terminate(_Reason, _State) ->
    stop_db().

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%% Internal functions
%handle_data(Socket, RawData, State) ->
%	Socket,
%	RawData,
%    State.

%%%
%%% VDR process will send message to this process. 
%%% This process will translate the message and send the new message to the database.
%%% At the same time, it will check whether the message from VDR should also be sent to the manage server or not.
%%% If so, this process will send the message to the process which is responsible for the talk to the management server.
%%%
%%%
db_message_processor(Ref) ->
	receive
        {FromPid, {data, Data}} ->
			% Communicate with DB here
			FromPid,
			process_message(FromPid, Ref, Data),
			db_message_processor(Ref);
		{FromPid, Data} ->
            ti_common:logerror("DB connection process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            db_message_processor(Ref);
		stop ->
			true
	after ?TIMEOUT_DATA_DB ->
        ti_common:loginfo("DB connection process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
        db_message_processor(Ref)
    end.

process_message(FromPid, Ref, Msg) ->
	FromPid,
    Ref,
	Msg.

stop_db() ->
    [{dbconnpid, DBConnPid}] = ets:lookup(msgservertable, dbconnpid),
    case DBConnPid of
        undefined ->
            ok;
        _ ->
            ets:insert(msgservertable, {dbconnpid, undefined}),
            DBConnPid!stop
    end,
    [{dbref, DBRef}] = ets:lookup(msgservertable, dbref),
    case DBRef of
        undefined ->
            ok;
        _ ->
             ets:insert(msgservertable, {dbref, undefined}),
             case odbc:disconnect(DBRef) of
                 ok ->
                     ok;
                 {error, Reason} ->
                     ti_common:logerror("Ignore when ODBC cannot disconnect correctly : ~p~n", [Reason])
             end,
             odbc:stop()
    end.
