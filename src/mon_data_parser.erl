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
        Size < 2 ->
            {error, lenerr};
        true ->
            ContentSize = Size-1,
            ContentBitSize = ContentSize*?LEN_BYTE,
            <<Content:ContentBitSize, Xor:?LEN_BYTE>> = RawData,
            CalcXor = vdr_data_parser:bxorbytelist(<<Content:ContentBitSize>>),
            if
                CalcXor =/= Xor ->
                    {error, xorerr};
                true ->
                    <<BodyLen:?LEN_BYTE, Body/binary>> = Content,
                    if
                        BodyLen =/= Size-2 ->
                            {error, lenerr};
                        true ->
                            if
                                BodyLen < 1 ->
                                    {error, lenerr};
                                true ->
                                    <<ID:?LEN_BYTE, Req/binary>> = Body,
                                    case ID of
                                        0 ->
                                            create_test_response();
                                        _ ->
                                            create_unknown_response()
                                    end
                            end
                    end
            end
    end.

create_msg(ID) when is_integer(ID),
                    ID < 255,
                    ID >= 0 ->
    Content = <<0:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	FinalLen = 2,
    <<FinalLen:?LEN_BYTE, Content/binary, Xor:?LEN_BYTE>>.
create_msg(ID, Body) when is_integer(ID),
                          ID < 255,
                          ID >= 0,
                          is_binary(Body) ->
    Len = byte_size(Body),
    Content = <<Len:?LEN_BYTE, Body/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	FinalLen = Len + 2,
    <<FinalLen:?LEN_BYTE, Content/binary, Xor:?LEN_BYTE>>.

create_unknown_response() ->
	create_msg(16#0).

create_test_response() ->
	create_msg(16#1).