%%%
%%% This file is use to parse the data from monitor
%%%

-module(cnum_data_parser).

-export([parse_data/2]).

-include("header.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_data(RawData, State) ->
    try do_process_data(RawData, State)
    catch
        _:Why ->
            [ST] = erlang:get_stacktrace(),
            common:logerr("Parsing CNUM data exception : ~p~n~p~nStack trace :~n~p", [Why, RawData, ST]),
            {error, exception, State}
    end.

do_process_data(RawData, State)
    Size = byte_size(RawData),
    if
		% LEN:1 byte, ID:1 byte, XOR:1 byte
		% So the minimum length should be 3
        Size < 3 ->
            create_error_resp(3);
        true ->
            ContentSize = Size-1,
            ContentBitSize = ContentSize*?LEN_BYTE,
            <<Content:ContentBitSize, Xor:?LEN_BYTE>> = RawData,
            CalcXor = vdr_data_parser:bxorbytelist(<<Content:ContentBitSize>>),
            if
                CalcXor =/= <<Xor:?LEN_BYTE>> ->
                    create_error_resp(4);
                true ->
                    <<BodyLen:?LEN_BYTE, Body/binary>> = <<Content:ContentBitSize>>,
                    if
                        BodyLen =/= Size-2 ->
                            create_error_resp(5);
                        true ->
                            <<ID:?LEN_BYTE, Req/binary>> = Body,
                            case ID of
                                0 ->
                                    create_test_conn_response();
                                _ ->
                                    create_unknown_msg_id_response(ID)
                            end
                    end
            end
    end.

get_data_binary(Data) ->
    IsList = is_list(Data),
    if
        IsList == true ->
            [BinData] = Data,
            BinData;
        true ->
            Data
    end.

%%%
%%% 0x7d0x1 -> 0x7d & 0x7d0x2 -> 0x7e
%%%
restore_7d_7e_msg(State, Data) ->
    Len = byte_size(Data),
    {Head, Remain} = split_binary(Data, 1),
    {Body, Tail} = split_binary(Remain, Len-2),
    if
        Head == <<16#7e>> andalso Tail == <<16#7e>> ->
            Result1 = binary:replace(Body, <<125,1>>, <<255,254,253,252,251,250,251,252,253,254,255>>, [global]),
            FinalResult1 = binary:replace(Result1, <<125,2>>, <<245,244,243,242,241,240,241,242,243,244,245>>, [global]),
            Result = binary:replace(FinalResult1, <<255,254,253,252,251,250,251,252,253,254,255>>, <<125>>, [global]),
            FinalResult = binary:replace(Result, <<245,244,243,242,241,240,241,242,243,244,245>>, <<126>>, [global]),
            {ok, FinalResult};
        true ->
            common:loginfo("Wrong data head/tail from ~p~n: (Head)~p / (Tail)~p",[State#vdritem.addr, Head, Tail]),
            error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
