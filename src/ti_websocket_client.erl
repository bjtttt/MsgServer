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
-define(CONNECTING, 0).
-define(OPEN, 1).
-define(CLOSED, 2).

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
            Request = "GET / HTTP/1.1\r\nUpgrade: WebSocket\r\nConnection: Upgrade\r\n" ++
                          "Host: " ++ Hostname ++ "\r\n" ++ "Origin: http://" ++ Hostname ++ "/\r\n\r\n",
            case gen_tcp:send(Socket, Request) of
                ok ->
                    inet:setopts(Socket, [{packet, http}]),    
                    Pid = self(),
                    WSPid = spawn(fun() -> msg2websocket_process(Pid, Socket) end),
                    ets:insert(msgservertable, {wspid, WSPid}),
                    {ok, #wsstate{socket=Socket, pid=Pid, wspid=WSPid}};
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

handle_cast(_Msg, State) ->    
    {noreply, State}. 

%% Start handshake
handle_info({http, Socket, {http_response, {1, 1}, 101, "Web Socket Protocol Handshake"}}, State) ->
    NewState = State#wsstate{state=?CONNECTING, socket=Socket},
    {noreply, NewState};
%% Extract the headers
handle_info({http, Socket, {http_header, _, Name, _, Value}},State) ->
    case State#wsstate.state of
        ?CONNECTING ->
            H = [{Name, Value} | State#wsstate.headers],
            NewState = State#wsstate{headers=H, socket=Socket},
            {noreply, NewState};
        undefined ->
            %% Bad state should have received response first
            {stop, error, State}
    end;
%% Once we have all the headers check for the 'Upgrade' flag 
handle_info({http, Socket, http_eoh}, State) ->
    %% Validate headers, set state, change packet type back to raw
    case State#wsstate.state of
        ?CONNECTING ->
            Headers = State#wsstate.headers,
            case proplists:get_value('Upgrade', Headers) of
                "WebSocket" ->
                    inet:setopts(Socket, [{packet, raw}]),
                    NewState = State#wsstate{state=?OPEN, socket=Socket},
                    {noreply, NewState};
                _Any  ->
                    {stop, error, State}
            end;
        undefined ->
            %% Bad state should have received response first
            {stop, error, State}
    end;
%% Handshake complete, handle packets
handle_info({tcp, _Socket, Data}, State) ->
    case State#wsstate.state of
        ?OPEN ->
            D = unframe(binary_to_list(Data)),
            {noreply, State};
        _Any ->
            {stop, error, State}
    end;
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
handle_info({tcp_error, _Socket, _Reason},State) ->
    {stop,tcp_error, State};
handle_info({'EXIT', _Pid, _Reason},State) ->
    {noreply, State}.

terminate(Reason, _State) ->
    ets:insert(msgservertable, {wspid, undefined}),
    error_logger:info_msg("Terminated ~p~n", [Reason]),
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

unframe([0|T]) -> unframe1(T).
unframe1([255]) -> [];
unframe1([H|T]) -> [H|unframe1(T)].

msg2websocket_process(Pid, Socket) ->
    receive
        {FromPid, {data, Data}} ->
            % Communicate with DB here
            FromPid,
            %process_message(FromPid, Ref, Data),
            msg2websocket_process(Pid, Socket);
        {FromPid, Data} ->
            ti_common:logerror("DB connection process : unknown message from PID ~p : ~p~n", [FromPid, Data]),
            msg2websocket_process(Pid, Socket);
        stop ->
            true
    after ?TIMEOUT_DATA_DB ->
        ti_common:loginfo("DB connection process : receiving PID message timeout after ~p~n", [?TIMEOUT_DB]),
        msg2websocket_process(Pid, Socket)
    end.


    
