%%%
%%%
%%%

-module(ti_common).

-export([number_list_to_binary/2,
         removemsgfromlistbyflownum/2,
         combine_strings/1,
         combine_strings/2]).

-export([set_sockopt/3]).

-export([safepeername/1, forcesafepeername/1, printsocketinfo/2, forceprintsocketinfo/2]).

-export([logerror/1, logerror/2, loginfo/1, loginfo/2]).

%%%
%%% Convert number list to binary.
%%% List    : [Num0, Num1, Num2, ...]
%%% NumLen  : Number length
%%% Return  : [<<Num0:NumLen>>, <<Num1:NumLen>>, <<Num2:NumLen>>, ...]
%%%
number_list_to_binary(List, NumLen) ->
    [H|T] = List,
    case T of
        [] ->
            <<H:NumLen>>;
        _ ->
            [<<H:NumLen>>|number_list_to_binary(T, NumLen)]
    end.

%%%
%%% Remove [FlowNumN, MsgN] according to FlowNum
%%% Msg : [[FlowNum0, Msg0], [FlowNum1, Msg1], [FlowNum2, Msg2], ...]
%%%
removemsgfromlistbyflownum(FlowNum, Msg) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [FN, _M] = H,
            if
                FN == FlowNum ->
                    removemsgfromlistbyflownum(FlowNum, T);
                FN =/= FlowNum ->
                    [H|removemsgfromlistbyflownum(FlowNum, T)]
            end
    end.

set_sockopt(LSock, CSock, Msg) ->    
    true = inet_db:register_socket(CSock, inet_tcp),    
    case prim_inet:getopts(LSock, [active, nodelay, keepalive, delay_send, priority, tos]) of       
        {ok, Opts} ->           
            case prim_inet:setopts(CSock, Opts) of              
                ok -> 
                    ok;             
                Error -> 
                    ti_common:logerror(string:concat(Msg, " prim_inet:setopts fails : ~p~n"), Error),    
                    gen_tcp:close(CSock)
            end;       
        Error ->           
            ti_common:logerror(string:concat(Msg, " prim_inet:getopts fails : ~p~n"), Error),
            gen_tcp:close(CSock)
    end.

%%%
%%% {ok {Address, Port}}
%%% {error, Reason|Why}
%%%
safepeername(Socket) ->
	try inet:peername(Socket) of
		{ok, {Address, Port}} ->
			{ok, {inet_parse:ntoa(Address), Port}};
		{error, Error} ->
			{error, Error}
	catch
		_:Reason ->
			{error, Reason}
	end.

%%%
%%% {ok, {Address, Port}}
%%% {ok, {"0.0.0.0", 0}}
%%%
forcesafepeername(Socket) ->
	try inet:peername(Socket) of
		{ok, {Address, Port}} ->
			{ok, {inet_parse:ntoa(Address), Port}};
		{error, _Error} ->
			{ok, {"0.0.0.0", 0}}
	catch
		_:_Reason ->
			{ok, {"0.0.0.0", 0}}
	end.

printsocketinfo(Socket, Msg) ->
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo(string:concat(Msg, " IP : ~p~n"), [Address]);
        {error, Error} ->
            ti_common:loginfo(string:concat(Msg, " unknown IP : ~p~n"), [Error])
    end.

forceprintsocketinfo(Socket, Msg) ->
    {ok, {Address, _Port}} = ti_common:forcesafepeername(Socket),
    ti_common:loginfo(string:concat(Msg, " IP : ~p~n"), [Address]).

logerror(Format) ->
    [{display, Display}] = ets:lookup(msgservertable, display),
    case Display of
        1 ->
            [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
            TimeStamp = calendar:now_to_local_time(erlang:now()),
            try
                case RawDisplay of
                    1 ->
                        io:format(string:concat("~p : ", Format), [TimeStamp]);
                    0 ->
                        error_logger:error_msg(string:concat("~p : ", Format), [TimeStamp]);
                    _ ->
                        ok
                end
            catch
                _:Why ->
                    case RawDisplay of
                        1 ->
                            io:format("~p : logerror fails : ~p~n", [TimeStamp, Why]);
                        0 ->
                            error_logger:error_msg("~p : logerror fails : ~p~n", [TimeStamp, Why]);
                        _ ->
                            ok
                    end
            end;
        _ ->
            ok
    end.

%%%
%%% Data is a list, for example : [], [Msg] or [Msg1, Msg2]
%%%
logerror(Format, Data) ->
    [{display, Display}] = ets:lookup(msgservertable, display),
    case Display of
        1 ->
            [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
            TimeStamp = calendar:now_to_local_time(erlang:now()),
            try
                TimeStamp = calendar:now_to_local_time(erlang:now()),
                case RawDisplay of
                    1 ->
                        io:format(string:concat("~p : ", Format), [TimeStamp | Data]);
                    0 ->
                        error_logger:error_msg(string:concat("~p : ", Format), [TimeStamp | Data]);
                    _ ->
                        ok
                end
            catch
                _:Why ->
                    case RawDisplay of
                        1 ->
                            io:format("~p : logerror fails : ~p~n", [TimeStamp, Why]);
                        0 ->
                            error_logger:error_msg("~p : logerror fails : ~p~n", [TimeStamp, Why]);
                        _ ->
                            ok
                    end
            end;
        _ ->
            ok
    end.

loginfo(Format) ->
    [{display, Display}] = ets:lookup(msgservertable, display),
    case Display of
        1 ->
            [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
            TimeStamp = calendar:now_to_local_time(erlang:now()),
            try
                TimeStamp = calendar:now_to_local_time(erlang:now()),
                case RawDisplay of
                    1 ->
                        io:format(string:concat("~p : ", Format), [TimeStamp]);
                    0 ->
                        error_logger:info_msg(string:concat("~p : ", Format), [TimeStamp]);
                    _ ->
                        ok
                end
            catch
                _:Why ->
                    case RawDisplay of
                        1 ->
                            io:format("~p : loginfo fails : ~p~n", [TimeStamp, Why]);
                        0 ->
                            error_logger:error_msg("~p : loginfo fails : ~p~n", [TimeStamp, Why]);
                        _ ->
                            ok
                    end
            end;
        _ ->
            ok
    end.

%%%
%%% Data is a list, for example : [], [Msg] or [Msg1, Msg2]
%%%
loginfo(Format, Data) ->
    [{display, Display}] = ets:lookup(msgservertable, display),
    case Display of
        1 ->
            [{rawdisplay, RawDisplay}] = ets:lookup(msgservertable, rawdisplay),
            TimeStamp = calendar:now_to_local_time(erlang:now()),
            try
                case RawDisplay of
                    1 ->
                        io:format(string:concat("~p : ", Format), [TimeStamp | Data]);
                    0 ->
                        error_logger:info_msg(string:concat("~p : ", Format), [TimeStamp | Data]);
                    _ ->
                        ok
                end
            catch
                _:Why ->
                    case RawDisplay of
                        1 ->
                            io:format("~p : loginfo fails : ~p~n", [TimeStamp, Why]);
                        0 ->
                            error_logger:error_msg("~p : loginfo fails : ~p~n", [TimeStamp, Why]);
                        _ ->
                            ok
                    end
            end;
        _ ->
            ok
    end.

%%%
%%% List must be string list.
%%% Otherwise, an empty string will be returned.
%%%
combine_strings(List) ->
    combine_strings(List, true).
combine_strings(List, HasComma) ->
    case List of
        [] ->
            "";
        _ ->
            Fun = fun(X) ->
                          case is_string(X) of
                              true ->
                                  true;
                              _ ->
                                  false
                          end
                  end,
            Bool = lists:all(Fun, List),
            case Bool of
                true ->
                    [H|T] = List,
                    case T of
                        [] ->
                            H;
                        _ ->
                            case HasComma of
                                true ->
                                    string:concat(string:concat(H, ","), combine_strings(T, HasComma));
                                _ ->
                                    string:concat(H, combine_strings(T, HasComma))
                            end
                    end;
                _ ->
                    ""
            end
    end.

%%%
%%%
%%%
is_string(Value) ->
    case is_list(Value) of
        true ->
            Fun = fun(X) ->
                          if X < 0 -> false; 
                             X > 255 -> false;
                             true -> true
                          end
                  end,
            lists:all(Fun, Value);
        _ ->
            false
    end.



