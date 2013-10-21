%%%
%%%
%%%

-module(common).

-include("header.hrl").

-export([split_msg_to_packages/2,
		 number_list_to_binary/2,
		 make_sure_n_byte_binary/2,
		 convert_integer_to_binary_string_list/1,
         convert_bcd_integer/1,
		 %convert_integer_bcd/1,
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
         integer_to_2byte_binary/1,
		 integer_to_size_binary/2,
		 integer_list_to_size_binary_list/2,
         float_to_binary/1,
         convert_gbk_to_utf8/1,
         convert_utf8_to_gbk/1,
		 get_str_bin_to_bin_list/1,
		 send_stat_err/2]).

-export([set_sockopt/3]).

-export([safepeername/1, forcesafepeername/1, printsocketinfo/2, forceprintsocketinfo/2]).

-export([logerror/1, logerror/2, loginfo/1, loginfo/2]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%%
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
split_msg_to_packages(Data, PackLen) when is_integer(PackLen),
							    		  PackLen > 0,
										  is_binary(Data),
										  PackLen =< byte_size(Data) ->
	Bins = do_split_msg_to_packages(Data, PackLen),
	Len = length(Bins),
	if
		Len > 1 ->
			add_sub_pack_suffix_to_bin_list(Bins, [], Len);%,
		true ->
			Bins
	end;
split_msg_to_packages(Data, PackLen) when is_integer(PackLen),
							    		  PackLen > 0,
										  is_binary(Data),
										  PackLen >= byte_size(Data) ->
	[Data];
split_msg_to_packages(_Data, _PackLen) ->
	[].

do_split_msg_to_packages(Data, PackLen) when is_integer(PackLen),
							    		     PackLen > 0,
										     is_binary(Data),
											 PackLen < byte_size(Data) ->
	Len = byte_size(Data),
	if
		PackLen >= Len ->
			[Data];
		true ->
			H = binary:part(Data, 0, PackLen),
			T = binary:part(Data, PackLen, Len-PackLen),
			%common:loginfo("Total size ~p : New subpackage size ~p : Left size ~p~n~p", [Len, byte_size(H), byte_size(T), H]),
			[H|do_split_msg_to_packages(T, PackLen)]
	end;
do_split_msg_to_packages(Data, PackLen) when is_integer(PackLen),
							    		     PackLen > 0,
										     is_binary(Data),
											 PackLen >= byte_size(Data)->
	[Data];
do_split_msg_to_packages(_Data, _PackLen) ->
	[].

add_sub_pack_suffix_to_bin_list(SrcList, DestList, TotalLen) when is_list(SrcList),
																  length(SrcList) > 0,
																  is_list(DestList) ->
	DestLen = length(DestList),
	[H|T] = SrcList,
	HNew = list_to_binary([?SUB_PACK_INDI_HEADER,
					       <<TotalLen:16>>,
					       <<(DestLen+1):16>>,
						   H]),
	DestListNew = lists:merge(DestList, [HNew]),
	add_sub_pack_suffix_to_bin_list(T, DestListNew, TotalLen);
add_sub_pack_suffix_to_bin_list(_SrcList, DestList, _TotalLen) when is_list(DestList) ->
	DestList;
add_sub_pack_suffix_to_bin_list(_SrcList, _DestList, _TotalLen) ->
	[].

make_sure_n_byte_binary(Bin, N) when is_binary(Bin),
									 N > 0 ->
	Size = bit_size(Bin),
	<<Int:Size>> = Bin,
	<<Int:(N*?LEN_BYTE)>>;
make_sure_n_byte_binary(_Bin, _N) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% Parameter 	: Integer = 48
%%% Output		: <<"48">>
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
integer_to_binary(Integer) when is_integer(Integer) ->
    list_to_binary(integer_to_list(Integer));
integer_to_binary(_Integer) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% Parameter 	: Integer = 48, ByteSize = 2
%%% Output		: <<0, 48>>
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
integer_to_size_binary(Integer, ByteSize) when is_integer(Integer),
										       is_integer(ByteSize),
										       ByteSize >= 0 ->
    <<Integer:(ByteSize*8)>>;
integer_to_size_binary(_Integer, _ByteSize) ->
    <<>>.


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Input : 5
% 	Must >= 0
% Output : 101
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_integer_to_binary_string_list(Int) when is_integer(Int),
												Int >= 0 ->
	Bit = Int band 1,
	BitChar = integer_to_list(Bit),
	NewInt = Int bsr 1,
	if
		NewInt > 0 ->
			lists:merge([convert_integer_to_binary_string_list(NewInt), BitChar]);
		true ->
			BitChar
	end;				
convert_integer_to_binary_string_list(Int) ->
	integer_to_list(Int).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%%
%%% Parameter 	: IDs = [48, 32], ByteSize = 2
%%% Output		: <<0, 48, 0, 32>>
%%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
integer_list_to_size_binary_list(IDs, ByteSize) when is_list(IDs),
						          		             length(IDs) > 0,
												     is_integer(ByteSize),
												     ByteSize >= 0 ->
	[H|T] = IDs,
	case T of
		[] ->
			common:integer_to_size_binary(H, ByteSize);
		_ ->
			list_to_binary([common:integer_to_size_binary(H, ByteSize), integer_list_to_size_binary_list(T, ByteSize)])
	end;
integer_list_to_size_binary_list(_IDs, _ByteSize) ->
	<<>>.

%%%
%%% It is only for this case : 10 -> <<"10">>
%%% Not for 10 -> <<0, 10>> which should use <<10:16>>
%%%
integer_to_2byte_binary(Integer) when is_integer(Integer) ->
    List = integer_to_list(Integer),
    Len = length(List),
    if
        Len > 1 ->
            list_to_binary(List);
        true ->
            list_to_binary(["0", List])
    end;
integer_to_2byte_binary(_Integer) ->
    <<>>.

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

%convert_integer_bcd(Number) ->
%	(Number div 10) * 16 + (Number rem 10).

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
            common:loginfo(string:concat(Msg, " from IP : ~p~n"), [Address]);
        {error, Error} ->
            common:loginfo(string:concat(Msg, " from unknown IP : ~p~n"), [Error])
    end.

forceprintsocketinfo(Socket, Msg) ->
    {ok, {Address, _Port}} = common:forcesafepeername(Socket),
    common:loginfo(string:concat(Msg, " IP : ~p~n"), [Address]).

%%%
%%%
%%%
logerror(Format) ->
    try %do_log_error(Format)
		error_logger:error_msg(Format)
    catch
        Oper:Msg ->
            error_logger:error_msg("logerror exception : (Operation)~p:(Message)~p~n", [Oper, Msg])
    end.

%do_log_error(Format) ->
%    [{display, Display}] = ets:lookup(msgservertable, display),
%    case Display of
%        1 ->
%            try
%                error_logger:error_msg(Format)
%            catch
%                _:Why ->
%                    error_logger:error_msg("logerror exception : ~p~n", Why)
%            end;
%        _ ->
%            ok
%    end.

%%%
%%% Data is a list, for example : [], [Msg] or [Msg1, Msg2]
%%%
logerror(Format, Data) when is_binary(Data)->
    try %do_log_error(Format, Data)
		error_logger:error_msg(Format, binary_to_list(Data))
    catch
        Oper:Msg ->
            error_logger:error_msg("logerror exception : (Operation)~p:(Message)~p~n", [Oper, Msg])
    end;
logerror(Format, Data) when is_list(Data)->
    try %do_log_error(Format, Data)
		error_logger:error_msg(Format, Data)
    catch
        Oper:Msg ->
            error_logger:error_msg("logerror exception : (Operation)~p:(Message)~p~n", [Oper, Msg])
    end;
logerror(_Format, _Data) ->
    error_logger:error_msg("logerror fails : not binary or list~n").
    
%do_log_error(Format, Data) when is_binary(Data) ->
%    [{display, Display}] = ets:lookup(msgservertable, display),
%    case Display of
%        1 ->
%            try
%                error_logger:error_msg(Format, binary_to_list(Data))
%            catch
%                _:Why ->
%                    error_logger:error_msg("logerror exception : ~p~n", Why)
%            end;
%        _ ->
%            ok
%    end;
%do_log_error(Format, Data) when is_list(Data) ->
%    [{display, Display}] = ets:lookup(msgservertable, display),
%    case Display of
%        1 ->
%            try
%                error_logger:error_msg(Format, Data)
%            catch
%                _:Why ->
%                    error_logger:error_msg("logerror exception : ~p~n", Why)
%            end;
%        _ ->
%            ok
%    end;
%do_log_error(_Format, _Data) ->
%    error_logger:error_msg("logerror fails : not binary or list~n").

%%%
%%%
%%%
loginfo(Format) ->
    try %do_log_info(Format)
		error_logger:info_msg(Format)
    catch
        Oper:Msg ->
            error_logger:error_msg("loginfo exception : (Operation)~p:(Message)~p~n", [Oper, Msg])
    end.

%do_log_info(Format) ->
%    [{display, Display}] = ets:lookup(msgservertable, display),
%    case Display of
%        1 ->
%            try
%                error_logger:info_msg(Format)
%            catch
%                _:Why ->
%                    error_logger:error_msg("loginfo exception : ~p~n", [Why])
%            end;
%        _ ->
%            ok
%    end.

%%%
%%% Data is a list, for example : [], [Msg] or [Msg1, Msg2]
%%%
loginfo(Format, Data) when is_binary(Data) ->
    try %do_log_info(Format, Data)
		error_logger:info_msg(Format, binary_to_list(Data))
    catch
        Oper:Msg ->
            error_logger:error_msg("loginfo exception : (Operation)~p:(Message)~p~n", [Oper, Msg])
    end;
loginfo(Format, Data) when is_list(Data) ->
    try %do_log_info(Format, Data)
		error_logger:info_msg(Format, Data)
    catch
        Oper:Msg ->
            error_logger:error_msg("loginfo exception : (Operation)~p:(Message)~p~n", [Oper, Msg])
    end;
loginfo(_Format, _Data) ->
    error_logger:error_msg("loginfo fails : not binary or list~n").

%do_log_info(Format, Data) when is_binary(Data) ->
%    [{display, Display}] = ets:lookup(msgservertable, display),
%    case Display of
%        1 ->
%           try
%                error_logger:info_msg(Format, binary_to_list(Data))
%            catch
%                _:Why ->
%                    error_logger:error_msg("loginfo exception : ~p~n", [Why])
%            end;
%        _ ->
%            ok
%    end;
%do_log_info(Format, Data) when is_list(Data) ->
%    [{display, Display}] = ets:lookup(msgservertable, display),
%    case Display of
%        1 ->
%           try
%                error_logger:info_msg(Format, Data)
%            catch
%                _:Why ->
%                    error_logger:error_msg("loginfo exception : ~p~n", [Why])
%            end;
%        _ ->
%            ok
%    end;
%do_log_info(_Format, _Data) ->
%    error_logger:error_msg("loginfo fails : not binary or list~n").

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
   
convert_utf8_to_gbk(Src) when is_binary(Src) orelse is_list(Src) ->
    [{ccpid, CCPid}] = ets:lookup(msgservertable, ccpid),
    CCPid ! {self(), utf82gbk, Src},
    receive
        undefined ->
            Src;
        Value ->
            Value
    after ?TIMEOUT_CC_PROCESS ->
            Src
    end;
convert_utf8_to_gbk(Src) ->
    Src.
    
convert_gbk_to_utf8(Src) when is_binary(Src) orelse is_list(Src) ->
    [{ccpid, CCPid}] = ets:lookup(msgservertable, ccpid),
    CCPid ! {self(), gbk2utf8, Src},
    receive
        undefined ->
            Src;
        Value ->
            Value
    after ?TIMEOUT_CC_PROCESS ->
            Src
    end;
convert_gbk_to_utf8(Src) ->
    Src.
    
get_str_bin_to_bin_list(S) when is_list(S),
							    length(S) > 0 ->
	B = list_to_binary(S),
	get_str_bin_to_bin_list(B);
get_str_bin_to_bin_list(S) when is_binary(S),
							    byte_size(S) > 0 ->
	H = binary:part(S, 0, 1),
	T = binary:part(S, 1, byte_size(S)-1),
	<<HInt:8>> = H,
	[integer_to_list(HInt)|get_str_bin_to_bin_list(T)];
get_str_bin_to_bin_list(_S) ->
	[].

send_stat_err(State, Type) ->
	if
		State#vdritem.linkpid =/= undefined ->
			State#vdritem.linkpid ! {self(), Type}
	end.









