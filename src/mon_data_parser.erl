%%%
%%% This file is use to parse the data from monitor
%%%

-module(mon_data_parser).

-export([parse_data/1]).

-include("header.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_data(RawData) ->
    Size = byte_size(RawData),
    if
        Size < 3 ->
            create_error_resp(2);
        true ->
            ContentSize = Size-1,
            ContentBitSize = ContentSize*?LEN_BYTE,
            <<Content:ContentBitSize, Xor:?LEN_BYTE>> = RawData,
            CalcXor = vdr_data_parser:bxorbytelist(<<Content:ContentBitSize>>),
            if
                CalcXor =/= <<Xor:?LEN_BYTE>> ->
                    create_error_resp(3);
                true ->
                    <<BodyLen:?LEN_BYTE, Body/binary>> = <<Content:ContentBitSize>>,
                    if
                        BodyLen =/= Size-2 ->
                            create_error_resp(4);
                        true ->
                            if
                                BodyLen < 1 ->
                                    {error, lenerr};
                                true ->
                                    <<ID:?LEN_BYTE, Req/binary>> = Body,
                                    case ID of
                                        0 ->
                                            create_test_conn_response();
                                        _ ->
                                            create_error_response()
                                    end
                            end
                    end
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% LEN:1 byte, STATE:1 byte, ID:1 byte, MSG:n bytes, XOR:1 byte
%
% STATE : 	0 - ok
%			1 - error with ID
%			2 - error without ID : length error
%			3 - error without ID : xor error
%			4 - error without ID : msg length error
%			5 - error without ID : internal error
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_msg(ID) when is_integer(ID),
                    ID =< 255,
                    ID >= 0 ->
    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, ID:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    <<Content/binary, Xor:?LEN_BYTE>>;
create_msg(_ID) ->
    Content = <<1:?LEN_BYTE, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    <<Content/binary, Xor:?LEN_BYTE>>.

create_msg(ID, Body) when is_integer(ID),
                          ID =< 255,
                          ID >= 0,
                          is_binary(Body) ->
    Len = byte_size(Body) + 1,
    Content = <<Len:?LEN_BYTE, ID:?LEN_BYTE, Body/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    <<Content/binary, Xor:?LEN_BYTE>>;
create_msg(_ID, _Body) ->
    Content = <<1:?LEN_BYTE, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    <<Content/binary, Xor:?LEN_BYTE>>.

create_error_resp(ErrID) when is_integer(ErrID),
							  ErrID >= 2,
							  ErrID =< 4 ->
	Content = <<1:?LEN_BYTE, ErrID:?LEN_BYTE>>,
	Xor = vdr_data_parser:bxorbytelist(Content),
	<<Content/binary, Xor:?LEN_BYTE>>;
create_error_resp(_ErrID) ->
    Content = <<1:?LEN_BYTE, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    <<Content/binary, Xor:?LEN_BYTE>>.

create_error_response() ->
	create_msg(16#FF).

create_test_conn_response() ->
    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, 0:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).
    %<<Content/binary, Xor:?LEN_BYTE>>.




