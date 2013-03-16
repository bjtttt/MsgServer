%%%
%%%
%%%

-module(ti_common).

-export([safepeername/1, printsocketinfo/2]).

-export([logerror/1, logerror/2, loginfo/1, loginfo/2]).

%%%
%%% {ok {Address, Port}}
%%% {error, Reason|Why}
%%%
safepeername(Socket) ->
	try inet:peername(Socket) of
		{ok, {Address, Port}} ->
			{ok, {inet_parse:ntoa(Address), Port}};
		{error, Reason} ->
			{error, Reason}
	catch
		_:Why ->
			{error, Why}
	end.

printsocketinfo(Socket, Msg) ->
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo(string:concat(Msg, " IP : ~p~n"), Address);
        {error, Explain} ->
            ti_common:loginfo(string:concat(Msg, " is unkown : ~p~n"), Explain)
    end.

logerror(Format) ->
    [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
    TimeStamp = calendar:now_to_local_time(erlang:now()),
    try
        case RawDisplay of
            1 ->
                io:format(string:concat("~p : ", Format), [TimeStamp]);
            _ ->
                error_logger:error_msg(string:concat("~p : ", Format), [TimeStamp])
        end
    catch
        _:Why ->
            case RawDisplay of
                1 ->
                    io:format("~p : logerror fails : ~p~n", [TimeStamp, Why]);
                _ ->
                    error_logger:error_msg("~p : logerror fails : ~p~n", [TimeStamp, Why])
            end
    end.

%%%
%%% Data is a list, for example : [], [Msg] or [Msg1, Msg2]
%%%
logerror(Format, Data) ->
    [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
    TimeStamp = calendar:now_to_local_time(erlang:now()),
    try
        TimeStamp = calendar:now_to_local_time(erlang:now()),
        case RawDisplay of
            1 ->
                io:format(string:concat("~p : ", Format), [TimeStamp | Data]);
            _ ->
                error_logger:error_msg(string:concat("~p : ", Format), [TimeStamp | Data])
        end
    catch
        _:Why ->
            case RawDisplay of
                1 ->
                    io:format("~p : logerror fails : ~p~n", [TimeStamp, Why]);
                _ ->
                error_logger:error_msg("~p : logerror fails : ~p~n", [TimeStamp, Why])
            end
    end.

loginfo(Format) ->
    [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
    TimeStamp = calendar:now_to_local_time(erlang:now()),
    try
        TimeStamp = calendar:now_to_local_time(erlang:now()),
        case RawDisplay of
            1 ->
                io:format(string:concat("~p : ", Format), [TimeStamp]);
            _ ->
                error_logger:info_msg(string:concat("~p : ", Format), [TimeStamp])
        end
    catch
        _:Why ->
            case RawDisplay of
                1 ->
                    io:format("~p : loginfo fails : ~p~n", [TimeStamp, Why]);
                _ ->
                    error_logger:error_msg("~p : loginfo fails : ~p~n", [TimeStamp, Why])
            end
    end.

%%%
%%% Data is a list, for example : [], [Msg] or [Msg1, Msg2]
%%%
loginfo(Format, Data) ->
    [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
    TimeStamp = calendar:now_to_local_time(erlang:now()),
    try
        case RawDisplay of
            1 ->
                io:format(string:concat("~p : ", Format), [TimeStamp | Data]);
            _ ->
                error_logger:info_msg(string:concat("~p : ", Format), [TimeStamp | Data])
        end
    catch
        _:Why ->
            case RawDisplay of
                1 ->
                    io:format("~p : loginfo fails : ~p~n", [TimeStamp, Why]);
                _ ->
                    error_logger:error_msg("~p : loginfo fails : ~p~n", [TimeStamp, Why])
            end
    end.




