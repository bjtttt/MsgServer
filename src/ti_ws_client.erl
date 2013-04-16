-module(ti_ws_client).

-behaviour(ti_websocket_client).

-include("ti_header.hrl").

-export([start/0,
         start/2]).

%% websocket specific callbacks
-export([onmessage/1,
         onopen/0,
         onclose/0,
         close/0,
         send/1]).

send(Data) ->
    websocket_client:write(Data).

start() ->
    websocket_client:start("localhost", 8002, ?MODULE).

start(Hostname, Port) ->
    websocket_client:start(Hostname, Port, ?MODULE).

onmessage(Data) ->
    io:format("Got some data:: ~p~n",[Data]).

onclose() ->
    io:format("Connection closed~n").

onopen() ->
    io:format("Connection open~n"),
    send("client-connected").

close() ->
    websocket_client:close().

