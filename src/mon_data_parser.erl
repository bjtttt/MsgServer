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
								11 ->
									create_undef_count_response();
								12 ->
									create_def_count_reponse();
								13 ->
									create_vehicle_stored_msg_info_reponse(Req);
								14 ->
									create_device_stored_msg_info_reponse(Req);
								15 ->
									create_ws_log_reponse(Req);
								16 ->
									create_db_log_reponse(Req);
								17 ->
									clear_ws_log_reponse(Req);
								18 ->
									clear_db_log_reponse(Req);
								19 ->
									get_ws_count_reponse(Req);
								20 ->
									get_db_count_reponse(Req);
								21 ->
									get_link_info_reponse(Req);
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
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, ID:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]);
create_msg(_ID) ->
    Content = <<1:?LEN_DWORD, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_msg(ID, Body) when is_integer(ID),
                          ID =< 255,
                          ID >= 0,
                          is_binary(Body) ->
    Len = byte_size(Body) + 1,
    Content = <<Len:?LEN_DWORD, ID:?LEN_BYTE, Body/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]);
create_msg(_ID, _Body) ->
    Content = <<1:?LEN_DWORD, 5:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_error_resp(ErrID) when is_integer(ErrID),
							  ErrID >= 3 ->
	Content = <<1:?LEN_DWORD, ErrID:?LEN_BYTE>>,
	Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_unknown_msg_id_response(ID) ->
	Content = <<2:?LEN_DWORD, 2:?LEN_BYTE, ID:?LEN_BYTE>>,
	Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_test_conn_response() ->
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 0:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

create_test_db_proc_response(DBPid) ->
	DBPid ! {self(), test},
	receive
		ok ->
		    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 1:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
		_ ->
		    Content = <<2:?LEN_DWORD, 1:?LEN_BYTE, 1:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

create_test_ws_proc_response(WSPid) ->
	WSPid ! {self(), test},
	receive
		ok ->
		    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 2:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
		_ ->
		    Content = <<2:?LEN_DWORD, 1:?LEN_BYTE, 2:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

create_vehicle_count_response() ->
	V1 = ets:info(vdrtable, size),
	if
		V1 == undefined ->
			Value1 = 0,
			Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 3:?LEN_BYTE, Value1:?LEN_DWORD>>,
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
		true ->
			Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 3:?LEN_BYTE, V1:?LEN_DWORD>>,
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

compose_one_item_list_array_to_list(IDs) when is_list(IDs),
											  length(IDs) > 0 ->
	[H|T] = IDs,
	if
		H == undefined ->
			compose_one_item_list_array_to_list(T);
		true ->
			lists:merge(H, compose_one_item_list_array_to_list(T))
	end;
compose_one_item_list_array_to_list(_IDs) ->
	[].

convert_integer_list_to_4_bytes_binary_list(IDList) when is_list(IDList),
														 length(IDList) > 0 ->
	[H|T] = IDList,
	if
		H == undefined ->
			convert_integer_list_to_4_bytes_binary_list(T);
		true ->
			case is_integer(H) of
				true ->
					list_to_binary([<<H:?LEN_DWORD>>, convert_integer_list_to_4_bytes_binary_list(T)]);
				_ ->
					convert_integer_list_to_4_bytes_binary_list(T)
			end
	end;
convert_integer_list_to_4_bytes_binary_list(_IDList) ->
	<<>>.

create_reset_all_response() ->
	Socks = ets:match(vdrtable, {'_', 
                                 '$1', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_', 
                                 '_', '_', '_', '_', '_',
								 '_', '_', '_', '_', '_', '_', '_', '_', '_'}),
	SockList = compose_one_item_list_array_to_list(Socks),
	close_all_sockets(SockList),
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 5:?LEN_BYTE>>,
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
					common:logerror("Exception when closing ~p:~p : ~p:~p~n", [Address, Port, Oper, Msg])
			end;
		{error, _Reason} ->
			try
				gen_tcp:close(H)
			catch
				Oper:Msg ->
					common:logerror("Exception when closing ~p : ~p:~p~n", [H, Oper, Msg])
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
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_', '_'}),
	%common:loginfo("vdrtable all device IDs : ~p~n", [DIDs]),
	DIDList = compose_one_item_list_array_to_list(DIDs),
	DIDsBin = convert_integer_list_to_4_bytes_binary_list(DIDList),
	Size = byte_size(DIDsBin),
    Content = <<(2+Size):?LEN_DWORD, 0:?LEN_BYTE, 5:?LEN_BYTE, DIDsBin/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).
		
create_all_vehicle_ids_response() ->
	VIDs = ets:match(vdrtable, {'_', 
                                '_', '_', '_', '_', '$1', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_', '_'}),
	VIDList = compose_one_item_list_array_to_list(VIDs),
	VIDsBin = convert_integer_list_to_4_bytes_binary_list(VIDList),
	Size = byte_size(VIDsBin),
    Content = <<(2+Size):?LEN_DWORD, 0:?LEN_BYTE, 6:?LEN_BYTE, VIDsBin/binary>>,
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
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_', '_'}),
    Count = length(VIDs),
    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 7:?LEN_BYTE, Count:?LEN_DWORD>>,
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
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_', '_'}),
    Count = length(VIDs),
    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 8:?LEN_BYTE, Count:?LEN_DWORD>>,
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
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_', '_'}),
    Count = length(VIDs),
    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 9:?LEN_BYTE, Count:?LEN_DWORD>>,
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
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_', '_'}),
    Count = length(VIDs),
    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 10:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_undef_count_response() ->
	VIDs = ets:match(vdrtable, {'_', 
                                '_', undefined, '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_'}),
	Count = length(VIDs),
    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 11:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_def_count_reponse() ->
	V1 = ets:info(vdrtable, size),
	VIDs = ets:match(vdrtable, {'_', 
                                '_', undefined, '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_', '_', '_', '_'}),
	Count = length(VIDs),
	case V1 of
		undefined ->
		    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 12:?LEN_BYTE, (-Count):?LEN_DWORD>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
		    list_to_binary([Content, Xor]);
		_ ->
		    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 12:?LEN_BYTE, (V1-Count):?LEN_DWORD>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
		    list_to_binary([Content, Xor])
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% [[ID0, MsgIdx0, Total0, Idx0, Body0], [ID1, MsgIdx1, Total1, Idx1, Body1], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_vehicle_stored_msg_info_reponse(VID) ->
    BS = bit_size(VID),
    <<VIDValue:BS>> = VID,
    Msgs = ets:match(vdrtable, {'_', 
                                '_', '_', '_', '_', VIDValue, 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'$1', '_', '_', '_', '_', '_', '_', '_', '_'}),
	[[RealMsgs]] = Msgs,
	Bin = convert_integer_list_list_to_4_byte_binary_list(RealMsgs),
	Size = byte_size(Bin),
    Content = <<(Size+2):?LEN_DWORD, 0:?LEN_BYTE, 13:?LEN_BYTE, Bin/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).	

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% [[ID0, MsgIdx0, Total0, Idx0, Body0], [ID1, MsgIdx1, Total1, Idx1, Body1], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_device_stored_msg_info_reponse(DID) ->
    BS = bit_size(DID),
    <<DIDValue:BS>> = DID,
    Msgs = ets:match(vdrtable, {'_', 
                                '_', DIDValue, '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'$1', '_', '_', '_', '_', '_', '_', '_', '_'}),
	[[RealMsgs]] = Msgs,
	Bin = convert_integer_list_list_to_4_byte_binary_list(RealMsgs),
	Size = byte_size(Bin),
    Content = <<(Size+2):?LEN_DWORD, 0:?LEN_BYTE, 14:?LEN_BYTE, Bin/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

convert_integer_list_list_to_4_byte_binary_list(List) when is_list(List),
														   length(List) > 0 ->
	[H|T] = List,
	HBin = convert_integer_list_to_4_bytes_binary_list(H),
	list_to_binary([HBin, convert_integer_list_list_to_4_byte_binary_list(T)]);
convert_integer_list_list_to_4_byte_binary_list(_List) ->
	<<>>.

create_ws_log_reponse(_Req) ->
    [{wslog, WSLog}] = ets:lookup(msgservertable, wslog),
	Msg = extract_log_info(WSLog, []),
	MsgLen = byte_size(Msg),
	Content = <<(MsgLen+2):?LEN_DWORD, 0:?LEN_BYTE, 15:?LEN_BYTE, Msg/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_db_log_reponse(_Req) ->
    [{dblog, DBLog}] = ets:lookup(msgservertable, dblog),
	Msg = extract_log_info(DBLog, []),
	MsgLen = byte_size(Msg),
	Content = <<(MsgLen+2):?LEN_DWORD, 0:?LEN_BYTE, 16:?LEN_BYTE, Msg/binary>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

extract_log_info(Log, Res) when is_list(Log),
								length(Log) > 0,
								is_list(Res) ->
	[H|T] = Log,
	{Num, S} = H,
	NumS = integer_to_list(Num),
	ItemS = lists:append(lists:append(lists:append(NumS, " - "), S), ";"),
	extract_log_info(T, lists:append(Res, ItemS));
extract_log_info(Log, Res) when is_list(Log),
								length(Log) == 0,
								is_list(Res) ->
	
	list_to_binary(Res);
extract_log_info(_Log, _Res) ->
	<<>>.

clear_ws_log_reponse(_Req) ->
    ets:insert(msgservertable, {wslog, []}),
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 17:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

clear_db_log_reponse(_Req) ->
    ets:insert(msgservertable, {dblog, []}),
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 18:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

get_ws_count_reponse(_Req) ->
	Res = ets:lookup(msgservertable, wspid),
	case Res of
		[{wspid, WSPid}] ->
			if
				WSPid =/= undefined ->
					WSPid ! {self(), count},
					receive
						{Num1, Num2} ->
							Content = <<10:?LEN_DWORD, 0:?LEN_BYTE, 19:?LEN_BYTE, Num1:?LEN_DWORD, Num2:?LEN_DWORD>>,
							Xor = vdr_data_parser:bxorbytelist(Content),
							list_to_binary([Content, Xor])
					end;
				true ->
					Content = <<10:?LEN_DWORD, 0:?LEN_BYTE, 19:?LEN_BYTE, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
					Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
			end;
		_ ->
			Content = <<10:?LEN_DWORD, 0:?LEN_BYTE, 19:?LEN_BYTE, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

get_db_count_reponse(_Req) ->
	Res = ets:lookup(msgservertable, dbpid),
	case Res of
		[{dbpid, DBPid}] ->
			if
				DBPid =/= undefined ->
					DBPid ! {self(), count},
					receive
						{Num1, Num2} ->
							Content = <<10:?LEN_DWORD, 0:?LEN_BYTE, 20:?LEN_BYTE, Num1:?LEN_DWORD, Num2:?LEN_DWORD>>,
							Xor = vdr_data_parser:bxorbytelist(Content),
							list_to_binary([Content, Xor])
					end;
				true ->
					Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 20:?LEN_BYTE, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
					Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
			end;
		_ ->
			Content = <<10:?LEN_DWORD, 0:?LEN_BYTE, 20:?LEN_BYTE, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

get_link_info_reponse(_Req) ->
	Res = ets:lookup(msgservertable, linkpid),
	case Res of
		[{linkpid, LinkPid}] ->
			if
				LinkPid =/= undefined ->
					LinkPid ! {self(), count},
					receive
						{Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9, Num10} ->
							Content = list_to_binary([<<46:?LEN_DWORD, 0:?LEN_BYTE, 21:?LEN_BYTE>>,
										<<Num1:?LEN_DWORD, Num2:?LEN_DWORD, Num3:?LEN_DWORD>>,
										<<Num4:?LEN_DWORD, Num5:?LEN_DWORD, Num6:?LEN_DWORD>>,
										<<Num7:?LEN_DWORD, Num8:?LEN_DWORD, Num9:?LEN_DWORD, Num10:?LEN_DWORD>>]),
							Xor = vdr_data_parser:bxorbytelist(Content),
							list_to_binary([Content, Xor])
					end;
				true ->
					Content = list_to_binary([<<46:?LEN_DWORD, 0:?LEN_BYTE, 21:?LEN_BYTE>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>]),
					Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
			end;
		_ ->
			Content = list_to_binary([<<46:?LEN_DWORD, 0:?LEN_BYTE, 21:?LEN_BYTE>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>]),
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.
