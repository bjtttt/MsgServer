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

handle_info({tcp, Socket, RawData}, State) ->
    NewState = handle_data(Socket, RawData, State),
    {noreply, NewState};
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
handle_info(timeout, State) ->
    case odbc:start(permanent) of
        ok ->
            [{dbdsn, DBDSN}] = ets:lookup(msgservertable, dbdsn),
            Connection = string:concat(string:concat("DSN=", DBDSN), "UID=aladdin;PWD=sesame"),
            case odbc:connect(Connection, []) of
                {ok, Ref} ->
                    {noreply, #dbstate{dbref=Ref}=State};
                {error, Reason} ->
                    ti_common:logerror("ODBC cannot connect ~p : ~p~n", [Connection, Reason]),
                    {stop, error, Reason}
            end;
        {error, Reason} ->
            ti_common:logerror("ODBC cannot start : ~p~n", [Reason]),
            {stop, error, Reason}
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

