%% 
%% Basic implementation of the WebSocket API:
%% http://dev.w3.org/html5/websockets/
%% However, it's not completely compliant with the WebSocket spec.
%% Specifically it doesn't handle the case where 'length' is included
%% in the TCP packet, SSL is not supported, and you don't pass a 'ws://type url to it.
%%
%% It also defines a behaviour to implement for client implementations.
%% @author Dave Bryson [http://weblog.miceda.org]
%%
-module(ti_websocket_client).

-behaviour(gen_server).

-include("ti_header.hrl").

%% API
-export([start_link/2]).

%% gen_server callbacks
-export([init/1, 
         handle_call/3,
         handle_cast/2,
         handle_info/2,
         terminate/2,
         code_change/3]).

%% Ready States

%% Behaviour definition
%-export([behaviour_info/1]).

%behaviour_info(callbacks) ->
%    [{onmessage, 1}, {onopen, 0}, {onclose, 0}, {close, 0}, {send, 1}];
%behaviour_info(_) ->
%    undefined.

start_link(Hostname, Port) ->
    gen_server:start_link(?MODULE, [Hostname, Port], []).

init([Hostname, Port]) ->
    process_flag(trap_exit, true),
    case gen_tcp:connect(Hostname, Port, [binary, {packet, 0}, {active,true}]) of
        {ok, Socket} ->
            Request = %"{\"MID\":0x0005, \"TOKEN\":\"anystring\"}",
                      [<<"GET / HTTP/1.1\r\nUpgrade: WebSocket\r\nConnection: Upgrade\r\n">>,
                        <<"Host: ">>, Hostname,
                        <<"\r\nSec-WebSocket-Key: ">>, generate_ws_key(),
                        <<"\r\nSec-WebSocket-Version: 13\r\n\r\n">>],
            case gen_tcp:send(Socket, Request) of
                ok ->
                    inet:setopts(Socket, [{packet, http}]),    
                    Pid = self(),
                    %WSPid = spawn(fun() -> msg2ws_process(Pid, Socket) end),
                    %ets:insert(msgservertable, {wspid, WSPid}),
                    {ok, #wsstate{socket=Socket, pid=Pid}};%, wspid=WSPid}};
                {error, Reason} ->
                    ti_common:logerror("WebSocket gen_tcp:send initial request fails : ~p~n", [Reason]),
                    {stop, tcp_error, Reason}
            end;
        {error, Reason} ->
            ti_common:logerror("WebSocket gen_tcp:connect fails : ~p~n", [Reason]),
            {stop, tcp_error, Reason}
    end.

handle_call(_Request, _From, State) ->
    {noreply, ok, State}.

handle_cast({send, Data}, State) ->
    gen_tcp:send(State#wsstate.socket,[0] ++ Data ++ [255]),
    {noreply, State};
handle_cast(close, State) ->
    gen_tcp:close(State#wsstate.socket),
    {stop, normal, State#wsstate{state=?CLOSED}};
handle_cast(_Msg, State) ->    
    {noreply, State}. 

%% Start handshake
%handle_info({http, Socket, {http_response, {1, 1}, 101, "Web Socket Protocol Handshake"}}, State) ->
%    {noreply, State#wsstate{state=?CONNECTING, socket=Socket}};
%% Extract the headers
%handle_info({http, Socket, {http_header, _, Name, _, Value}},State) ->
%    case State#wsstate.state of
%        ?CONNECTING ->
%            H = [{Name, Value} | State#wsstate.headers],
%            {noreply, State#wsstate{headers=H, socket=Socket}};
%        undefined ->
%            %% Bad state should have received response first
%            {stop, error, State}
%    end;
%% Once we have all the headers check for the 'Upgrade' flag 
%handle_info({http, Socket, http_eoh}, State) ->
%    %% Validate headers, set state, change packet type back to raw
%    case State#wsstate.state of
%        ?CONNECTING ->
%            Headers = State#wsstate.headers,
%            case proplists:get_value('Upgrade', Headers) of
%                "WebSocket" ->
%                    inet:setopts(Socket, [{packet, raw}]),
%                    NewState = State#wsstate{state=?OPEN, socket=Socket},
%                    {noreply, NewState};
%                _Any  ->
%                    {stop, error, State}
%            end;
%        undefined ->
%            %% Bad state should have received response first
%            {stop, error, State}
%    end;
%% Handshake complete, handle packets
handle_info({tcp, Socket, Data}, State) ->
    List = binary_to_list(Data),
    case State#wsstate.state of
        ?CONNECTING ->
            HandShakeHead = [<<"HTTP/1.1 101 Switching Protocols\r\n">>,
                             <<"Server: libwebsock/1.0.1\r\n">>,
                             <<"Upgrade: websocket\r\n">>,
                             <<"Connection: Upgrade\r\n">>,
                             <<"Sec-WebSocket-Accept: ">>],
            Len = length(HandShakeHead),
            LenData = length(List),
            if
                (Len+4) >= LenData ->
                    {noreply, State};
                true ->
                    DataHead = lists:sublist(List, Len),
                    case DataHead of
                        HandShakeHead ->
                            WSAccKey = lists:sublist(List, Len+1, LenData-Len-4),
                            {noreply, State#wsstate{state=?OPEN, socket=Socket, wsacckey=WSAccKey}};
                        _ ->
                            {noreply, State}
                    end
            end;
        ?OPEN ->
            Body = unframe(binary_to_list(Data)),
            case ti_man_data_parser:process_data(Body) of
                {ok, Mid, Res} ->
                    {noreply, State};
                {error, _Error} ->
                    {noreply, State}
            end;
        _Any ->
            {stop, error, State}
    end;
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
handle_info({tcp_error, _Socket, _Reason},State) ->
    {stop,tcp_error, State};
handle_info({'EXIT', _Pid, _Reason},State) ->
    {noreply, State}.

terminate(Reason, State) ->
    ets:insert(msgservertable, {wspid, undefined}),
    WSPid = State#wsstate.wspid,
    WSPid!stop,    
    error_logger:error_msg("WS client is terminated ~p~n", [Reason]),
    error_logger:error_msg("Msg server is terminated~n"),
    application:stop(ti_app).

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

unframe([0|T]) -> unframe1(T).
unframe1([255]) -> [];
unframe1([H|T]) -> [H|unframe1(T)].

msg2ws_process(Pid, Sock) ->
    receive
        {FromPid, {data, Data}} ->
            % Communicate with DB here
            FromPid,
            %process_message(FromPid, Ref, Data),
            gen_server:cast(?MODULE, {send, Data}),
            msg2ws_process(Pid, Sock);
        {FromPid, Data} ->
            ti_common:logerror("msg2ws process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            msg2ws_process(Pid, Sock);
        stop ->
            true
    after ?TIMEOUT_MAN ->
        ti_common:loginfo("msg2ws process : timeout~n", [?TIMEOUT_MAN]),
        msg2ws_process(Pid, Sock)
    end.

%% @doc Key sent in initial handshake
-spec generate_ws_key() ->
    binary().
generate_ws_key() ->
    base64:encode(crypto:rand_bytes(16)).

    
