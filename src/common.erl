%%%
%%%
%%%

-module(common).

-export([number_list_to_binary/2,
         convert_bcd_integer/1,
         removemsgfromlistbyflownum/2,
         combine_strings/1,
         combine_strings/2,
         split_msg_to_single/2,
         is_string/1,
         is_string_list/1,
         is_integer_string/1,
         is_dec_integer_string/1,
         is_hex_integer_string/1,
         is_dec_list/1,
         convert_word_hex_string_to_integer/1,
		 integer_to_binary/1,
         float_to_binary/1]).

-export([set_sockopt/3]).

-export([safepeername/1, forcesafepeername/1, printsocketinfo/2, forceprintsocketinfo/2]).

-export([logerror/1, logerror/2, loginfo/1, loginfo/2]).

%%%
%%%
%%%
integer_to_binary(Integer) ->
    list_to_binary(integer_to_list(Integer)).

%%%
%%%
%%%
float_to_binary(Float) ->
    list_to_binary(float_to_list(Float)).

%%%
%%%
%%%
convert_bcd_integer(Number) ->
    (Number div 16) * 10 + (Number rem 16).

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
                    common:logerror(string:concat(Msg, " prim_inet:setopts fails : ~p~n"), Error),    
                    gen_tcp:close(CSock)
            end;       
        Error ->           
            common:logerror(string:concat(Msg, " prim_inet:getopts fails : ~p~n"), Error),
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
    case common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            common:loginfo(string:concat(Msg, " IP : ~p~n"), [Address]);
        {error, Error} ->
            common:loginfo(string:concat(Msg, " unknown IP : ~p~n"), [Error])
    end.

forceprintsocketinfo(Socket, Msg) ->
    {ok, {Address, _Port}} = common:forcesafepeername(Socket),
    common:loginfo(string:concat(Msg, " IP : ~p~n"), [Address]).

%%%
%%%
%%%
logerror(Format) ->
    try do_log_error(Format)
    catch
        _:_ ->
            ok
    end.

do_log_error(Format) ->
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
    try do_log_error(Format, Data)
    catch
        _:_ ->
            ok
    end.
    
do_log_error(Format, OriData) ->
    [{display, Display}] = ets:lookup(msgservertable, display),
    case is_binary(OriData) of
        true ->
            Data = binary_to_list(OriData),
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
            end;
        _ ->
            Data = OriData,
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
            end
    end.

%%%
%%%
%%%
loginfo(Format) ->
    try do_log_info(Format)
    catch
        _:_ ->
            ok
    end.

do_log_info(Format) ->
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
    try do_log_info(Format, Data)
    catch
        _:_ ->
            ok
    end.

do_log_info(Format, RawData) ->
    [{display, Display}] = ets:lookup(msgservertable, display),
    case is_binary(RawData) of
        true ->
            Data = binary_to_list(RawData),
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
            end;
        _ ->
            Data = RawData,
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
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% List must be string list.
% Otherwise, an empty string will be returned.
% combine_strings(List, HasComma = true)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
combine_strings(List) when is_list(List)->
    combine_strings(List, true);
combine_strings(_List) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% List must be string list.
% Otherwise, an empty string will be returned.
% combine_strings(List, HasComma = true)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
combine_strings(List, HasComma) when is_list(List),
                                     is_boolean(HasComma) ->
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
    end;
combine_strings(_List, _HasComma) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   true only when Value is NOT an empty string
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_string(Value) when is_list(Value) ->
    Len = length(Value),
    if
        Len < 1 ->
            false;
        true ->
            Fun = fun(X) ->
                          if X < 0 -> false; 
                             X > 255 -> false;
                             true -> true
                          end
                  end,
            lists:all(Fun, Value)
    end;
is_string(_Value) ->
    false.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% true only when Value is NOT an empty integer string
% For example, "81", "8A" and "0x8B" is false
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_integer_string(Value) when is_list(Value) ->
    Len = length(Value),
    if
        Len < 1 ->
            false;
        true ->
            Fun = fun(X) ->
                          if X < 48 orelse X > 57 -> 
                                 if
                                     X == 88 orelse X == 120 ->
                                         true;
                                     true ->
                                         false
                                 end;                                     
                             true -> true
                          end
                  end,
            lists:all(Fun, Value)
    end;
is_integer_string(_Value) ->
    false.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_dec_list(List) when is_list(List),
                       length(List) > 0 ->
    
    Fun = fun(X) ->
                  case is_integer(X) of
                      true -> true;
                      _ -> false
                  end
          end,
    lists:all(Fun, List).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Check whether "NNNN", "NN" or any string like this format to be a valid decimal string or not.
% For example, "81" is true while "8A" is false
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_dec_integer_string(Value) when is_list(Value) ->
    Len = length(Value),
    if
        Len < 1 ->
            false;
        true ->
            Fun = fun(X) ->
                          if 
                              X < 48 orelse X > 57 -> 
                                false;
                              true -> true
                          end
                  end,
            lists:all(Fun, Value)
    end;
is_dec_integer_string(_Value) ->
    false.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Check whether "NNNN", "NN" or any string like this format to be a valid hex string or not.
% For example, "81" and "8A" are both true
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_hex_integer_string(Value) when is_list(Value) ->
    case is_integer_string(Value) of
        true ->
            Lenx = length(string:tokens(Value, "0x")),
            LenX = length(string:tokens(Value, "0x")),
            if
                Lenx == 1 orelse LenX == 1 ->
                    true;
                true ->
                    false
            end;
        _ ->
            false
    end;
is_hex_integer_string(_Value) ->
    false.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% WordHexString : 32 bit
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_word_hex_string_to_integer(WordHexStr) when is_list(WordHexStr) ->
    case is_hex_integer_string(WordHexStr) of
        true ->
            [_Pre, Value] = string:tokens(WordHexStr, "xX"),
            Hex = list_to_integer(Value),
            First = Hex div 1000,
            Second = Hex div 100,
            Third = Hex div 10,
            Fourth = Hex rem 10,
            First * 16 * 16 * 16 + Second * 16 * 16 + Third * 16 + Fourth;
        _ ->
            0
    end;
convert_word_hex_string_to_integer(_WordHexStr) ->
    0.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   true only when all strings in List are NOT an empty one
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
is_string_list(List) when is_list(List) ->
    Len = length(List),
    if
        Len < 1 ->
            false;
        true ->
            Fun = fun(X) ->
                          case is_string(X) of
                              true -> true;
                              %false -> false;
                              _ -> false
                          end
                  end,
            lists:all(Fun, List)
    end;
is_string_list(_List) ->
    false.

%%%
%%% Msg structure :
%%%     Flag    : == 1 byte
%%%     Head    : 11 or 15 bytes
%%%     Body    : >= 0 bytes
%%%     Parity  : == 1 byte
%%%     Flag    : == 1 byte
%%%
split_msg_to_single(Msg, Tag) ->
    List = binary_to_list(Msg),
    Len = length(List),
    if
        Len < 15 ->
            [];
        true ->
            HeadFlag = lists:nth(1, List),
            HeadFlag1 = lists:nth(2, List),
            TailFlag = lists:nth(Len, List),
            TailFlag1 = lists:nth(Len-1, List),
            if
                HeadFlag == 16#7e andalso TailFlag == 16#7e andalso HeadFlag1 =/= 16#7e andalso TailFlag1 =/= 16#7e ->
                    Mid = lists:sublist(List, 2, Len-2),
                    BinMid = list_to_binary(Mid),
                    BinMidNew = binary:replace(BinMid, <<16#7e, 16#7e>>, <<16#ff>>, [global]),
                    BinMidNewStr = binary_to_list(BinMidNew),
                    Index = string:str(BinMidNewStr, binary_to_list(<<16#7e>>)),
                    if
                        Index == 0 ->
                            [list_to_binary([<<16#7e>>, BinMidNew, <<16#7e>>])];
                        true ->
                            split_list(List, Tag)
                    end;
                true ->
                    []
            end
    end.

%%%
%%%
%%%
split_list(List, Tag) ->
    case List of
        [] ->
            [];
        _ ->
            {L11, L12} = lists:splitwith(fun(A) -> A =/= Tag end, List),
            {L21, L22} = lists:splitwith(fun(A) -> A == Tag end, List),
            case L11 of
                [] ->
                    case L21 of
                        [Tag] ->
                            split_list(L22, Tag);
                        [Tag, Tag] ->
                            split_list(L22, Tag);
                        _ ->
                            List22 = split_list(L22, Tag),
                            case List22 of
                                [] ->
                                    [list_to_binary([<<126>>, list_to_binary(L21), <<126>>])];
                                _ ->
                                    [list_to_binary([<<126>>, list_to_binary(L21), <<126>>])|List22]
                            end
                    end;
                _ ->
                    case L11 of
                        [Tag] ->
                            split_list(L12, Tag);
                        [Tag, Tag] ->
                            split_list(L12, Tag);
                        _ ->
                            List12 = split_list(L12, Tag),
                            case List12 of
                                [] ->
                                    [list_to_binary([<<126>>, list_to_binary(L11), <<126>>])];
                                _ ->
                                    [list_to_binary([<<126>>, list_to_binary(L11), <<126>>])|List12]
                            end
                    end
            end
    end.
    
    
    

