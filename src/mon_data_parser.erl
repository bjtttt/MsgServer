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
								3 ->
									create_vehicle_count_response();
 								4 ->
									create_reset_all_response();
								5 ->
									create_all_device_ids_response();
                                6 ->
                                    create_all_vehicle_ids_response();
                                7 ->
                                    create_spec_vehicle_count_response(Req);
                                8 ->
                                    create_spec_device_count_response(Req);
                                9 ->
                                    create_spec_vehicle_info_response(Req);
                                10 ->
                                    create_spec_device_info_response(Req);
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

create_vehicle_count_response() ->
	V1 = ets:info(vdrtable, size),
	if
		V1 == undefined ->
			Value1 = 0,
			Content = <<6:?LEN_BYTE, 0:?LEN_BYTE, 3:?LEN_BYTE, Value1:?LEN_DWORD>>,
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
		true ->
			Content = <<6:?LEN_BYTE, 0:?LEN_BYTE, 3:?LEN_BYTE, V1:?LEN_DWORD>>,
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

compose_one_item_list_array_to_list(IDs) when is_list(IDs),
											  length(IDs) > 0 ->
	[H|T] = IDs,
	lists:merge(H, compose_one_item_list_array_to_list(T));
compose_one_item_list_array_to_list(_IDs) ->
	[].

convert_integer_list_to_4_bytes_binary_list(IDList) when is_list(IDList),
														 length(IDList) > 0 ->
	[H|T] = IDList,
	list_to_binary([<<H:?LEN_DWORD>>, convert_integer_list_to_4_bytes_binary_list(T)]);
convert_integer_list_to_4_bytes_binary_list(_IDList) ->
	<<>>.

create_reset_all_response() ->
	Socks = ets:match(vdrtable, {'_', 
                                 '$1', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', '_', '_'}),
	%common:loginfo("vdrtable all sockets : ~p~n", [Socks]),
	SockList = compose_one_item_list_array_to_list(Socks),
	close_all_sockets(SockList),
    Content = <<2:?LEN_BYTE, 0:?LEN_BYTE, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

close_all_sockets(SockList) when is_list(SockList),
								 length(SockList) > 0 ->
	[H|T] = SockList,
	case common:safepeername(H) of
		{ok, {Address, Port}} ->
			try
				gen_tcp:close(H)
			catch
				Oper:Msg ->
					common:logerror("Exception when closing ~p:~p : ~p:~p", [Address, Port, Oper, Msg])
			end;
		{error, _Reason} ->
			try
				gen_tcp:close(H)
			catch
				Oper:Msg ->
					common:logerror("Exception when closing ~p : ~p:~p", [H, Oper, Msg])
			end
	end,
	close_all_sockets(T);
close_all_sockets(_SockList) ->
	ok.
		
create_all_device_ids_response() ->
	DIDs = ets:match(vdrtable, {'_', 
                                '_', '$1', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', '_', '_'}),
	%common:loginfo("vdrtable all device IDs : ~p~n", [DIDs]),
	DIDList = compose_one_item_list_array_to_list(DIDs),
	DIDsBin = convert_integer_list_to_4_bytes_binary_list(DIDList),
	Size = byte_size(DIDsBin),
    Content = <<(2+Size):?LEN_BYTE, 0:?LEN_BYTE, 5:?LEN_BYTE, DIDsBin/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).
		
create_all_vehicle_ids_response() ->
	VIDs = ets:match(vdrtable, {'_', 
                                '_', '_', '_', '_', '$1', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', '_', '_'}),
	%common:loginfo("vdrtable all vehicle IDs : ~p~n", [VIDs]),
	VIDList = compose_one_item_list_array_to_list(VIDs),
	VIDsBin = convert_integer_list_to_4_bytes_binary_list(VIDList),
	Size = byte_size(VIDsBin),
    Content = <<(2+Size):?LEN_BYTE, 0:?LEN_BYTE, 6:?LEN_BYTE, VIDsBin/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_spec_vehicle_count_response(VID) ->
    BS = bit_size(VID),
    <<VIDValue:BS>> = VID,
    VIDs = ets:match(vdrtable, {'$1', 
                                '_', '_', '_', '_', VIDValue, 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', '_', '_'}),
    %common:loginfo("vdrtable all vehicles : ~p~n", [VIDs]),
    Count = length(VIDs),
    Content = <<6:?LEN_BYTE, 0:?LEN_BYTE, 7:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_spec_device_count_response(DID) ->
    BS = bit_size(DID),
    <<DIDValue:BS>> = DID,
    VIDs = ets:match(vdrtable, {'$1', 
                                '_', DIDValue, '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', '_', '_'}),
    %common:loginfo("vdrtable all devices : ~p~n", [VIDs]),
    Count = length(VIDs),
    Content = <<6:?LEN_BYTE, 0:?LEN_BYTE, 8:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_spec_vehicle_info_response(VID) ->
    BS = bit_size(VID),
    <<VIDValue:BS>> = VID,
    VIDs = ets:match(vdrtable, {'$1', 
                                '_', '_', '_', '_', VIDValue, 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', '_', '_'}),
    Count = length(VIDs),
    Content = <<6:?LEN_BYTE, 0:?LEN_BYTE, 7:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_spec_device_info_response(DID) ->
    BS = bit_size(DID),
    <<DIDValue:BS>> = DID,
    VIDs = ets:match(vdrtable, {'$1', 
                                '_', DIDValue, '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', '_', '_'}),
    Count = length(VIDs),
    Content = <<6:?LEN_BYTE, 0:?LEN_BYTE, 8:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).





