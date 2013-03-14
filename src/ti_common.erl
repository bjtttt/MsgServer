%%%
%%%
%%%

-module(ti_common).

-export([safepeername/1, logerror/1, logerror/2, loginfo/1, loginfo/2]).

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

logerror(Format) ->
    try
        TimeStamp = calendar:now_to_local_time(erlang:now()),
        error_logger:error_msg(string:concat("~p : ", Format), [TimeStamp])
    catch
        _:Why ->
            ETimeStamp = calendar:now_to_local_time(erlang:now()),
            error_logger:error_msg("~p : logerror fails : ~p~n", [ETimeStamp, Why])
    end.

logerror(Format, Data) ->
    try
        TimeStamp = calendar:now_to_local_time(erlang:now()),
        error_logger:error_msg(string:concat("~p : ", Format), [TimeStamp, Data])
    catch
        _:Why ->
            ETimeStamp = calendar:now_to_local_time(erlang:now()),
            error_logger:error_msg("~p : logerror fails : ~p~n", [ETimeStamp, Why])
    end.

loginfo(Format) ->
    try
        TimeStamp = calendar:now_to_local_time(erlang:now()),
        error_logger:info_msg(string:concat("~p : ", Format), [TimeStamp])
    catch
        _:Why ->
            ETimeStamp = calendar:now_to_local_time(erlang:now()),
            error_logger:error_msg("~p : loginfo fails : ~p~n", [ETimeStamp, Why])
    end.

loginfo(Format, Data) ->
    try
        TimeStamp = calendar:now_to_local_time(erlang:now()),
        error_logger:info_msg(string:concat("~p : ", Format), [TimeStamp, Data])
    catch
        _:Why ->
            ETimeStamp = calendar:now_to_local_time(erlang:now()),
            error_logger:error_msg("~p : loginfo fails : ~p~n", [ETimeStamp, Why])
    end.





