%%%
%%% This file is use to parse the data from monitor
%%%

-module(mon_data_parser).

-export([parse_data/2]).

-include("header.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_data(RawData, State) ->
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
								1 ->
									create_test_db_proc_response(State#monitem.dbpid);
								2 ->
									create_test_ws_proc_response(State#monitem.wspid);
                                _ ->
                                    create_unknown_msg_id_response(ID)
                            end
                    end
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% STATE : 0, 1
% LEN:1 byte, STATE:1 byte, ID:1 byte, MSG:n bytes, XOR:1 byte
%
% STATE : 3, 4, 5, 6
% LEN:1 byte, STATE:1 byte, XOR:1 byte
%
% STATE : 	0 - ok
%			1 - error with ID
%			2 - unknown ID with ID
%			3 - error without ID : length error
%			4 - error without ID : xor error
%			5 - error without ID : msg length error
%			6 - error without ID : internal error
%			_ - error without ID : unknown
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_msg(ID) when is_integer(ID),
                    ID =< 255,
                    ID >= 0 ->
    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, ID:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]);
create_msg(_ID) ->
    Content = <<1:?LEN_BYTE, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_msg(ID, Body) when is_integer(ID),
                          ID =< 255,
                          ID >= 0,
                          is_binary(Body) ->
    Len = byte_size(Body) + 1,
    Content = <<Len:?LEN_BYTE, ID:?LEN_BYTE, Body/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]);
create_msg(_ID, _Body) ->
    Content = <<1:?LEN_BYTE, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_error_resp(ErrID) when is_integer(ErrID),
							  ErrID >= 3 ->
	Content = <<1:?LEN_BYTE, ErrID:?LEN_BYTE>>,
	Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_unknown_msg_id_response(ID) ->
	Content = <<2:?LEN_BYTE, 2:?LEN_BYTE, ID:?LEN_BYTE>>,
	Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_test_conn_response() ->
    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, 0:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_test_db_proc_response(DBPid) ->
	DBPid ! {self(), test},
	receive
		ok ->
		    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, 1:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
		_ ->
		    Content = <<2:?LEN_BYTE, 1:?LEN_BYTE, 1:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

create_test_ws_proc_response(WSPid) ->
	WSPid ! {self(), test},
	receive
		ok ->
		    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, 2:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
		_ ->
		    Content = <<2:?LEN_BYTE, 1:?LEN_BYTE, 2:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.






