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
								22 ->
									clear_link_info_reponse(Req);
								23 ->
									read_db_chinese_reponse(Req);
								24 ->
									read_db_chinese_init_reponse(Req);
								25 ->
									get_system_info_reponse(Req);
								26 ->
									get_driver_count_response(State);
								27 ->
									set_vdr_log(Req, State);
								28 ->
									clear_vdr_log(Req, State);
								29 ->
									reset_vdr_log(State);
								30 ->
									get_vdr_log(State);
								31 ->
									get_vdr_online_count(State);
								32 ->
									get_vdr_online(Req, State);
								33 ->
									clear_vdr_online(Req, State);
								34 ->
									reset_vdr_online(State);
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
%create_msg(ID) when is_integer(ID),
%                    ID =< 255,
%                    ID >= 0 ->
%    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, ID:?LEN_BYTE>>,
%    Xor = vdr_data_parser:bxorbytelist(Content),
%    list_to_binary([Content, Xor]);
%create_msg(_ID) ->
%    Content = <<1:?LEN_DWORD, 5:?LEN_BYTE>>,
%    Xor = vdr_data_parser:bxorbytelist(Content),
%    list_to_binary([Content, Xor]).

%create_msg(ID, Body) when is_integer(ID),
%                          ID =< 255,
%                          ID >= 0,
%                          is_binary(Body) ->
%    Len = byte_size(Body) + 1,
%    Content = <<Len:?LEN_DWORD, ID:?LEN_BYTE, Body/binary>>,
%    Xor = vdr_data_parser:bxorbytelist(Content),
%    list_to_binary([Content, Xor]);
%create_msg(_ID, _Body) ->
%    Content = <<1:?LEN_DWORD, 5:?LEN_BYTE>>,
%    Xor = vdr_data_parser:bxorbytelist(Content),
%    list_to_binary([Content, Xor]).

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
    Pid = self(),
	V1 = common:send_vdr_table_operation(undefined, {Pid, count}),
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
                                 '_', '_', '_', '_', '_',
                                 '_', '_', '_', '_', '_',
								 '_', '_', '_', '_', '_',
								 '_'}),
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
					common:loginfo("Exception when closing ~p:~p : ~p:~p~n", [Address, Port, Oper, Msg])
			end;
		{error, _Reason} ->
			try
				gen_tcp:close(H)
			catch
				Oper:Msg ->
					common:loginfo("Exception when closing ~p : ~p:~p~n", [H, Oper, Msg])
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
                                '_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
								'_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
	Count = length(VIDs),
    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 11:?LEN_BYTE, Count:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
    list_to_binary([Content, Xor]).

create_def_count_reponse() ->
    Pid = self(),
	V1 = common:send_vdr_table_operation(undefined, {Pid, count}),
	VIDs = ets:match(vdrtable, {'_', 
                                '_', undefined, '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_', 
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '$1',
                                '_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
                                '_', '_', '_', '_', '$1',
                                '_', '_', '_', '_', '_',
                                '_', '_', '_', '_', '_',
								'_', '_', '_', '_', '_',
								'_'}),
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
						{Num1, Num2, Num3, Num4, Num5, Num6, Num7, Num8, Num9, Num10, 
						Num11, Num12, Num13, Num14, Num15, Num16, Num17, Num18, Num19, 
						Num20, Num21, Num22, Num23, Num24, Num25, Num26} ->
							Content = list_to_binary([<<106:?LEN_DWORD, 0:?LEN_BYTE, 21:?LEN_BYTE>>,
										<<Num1:?LEN_DWORD, Num2:?LEN_DWORD, Num3:?LEN_DWORD>>,
										<<Num4:?LEN_DWORD, Num5:?LEN_DWORD, Num6:?LEN_DWORD>>,
										<<Num7:?LEN_DWORD, Num8:?LEN_DWORD, Num9:?LEN_DWORD>>, 
										<<Num10:?LEN_DWORD, Num11:?LEN_DWORD, Num12:?LEN_DWORD>>, 
										<<Num13:?LEN_DWORD, Num14:?LEN_DWORD, Num15:?LEN_DWORD>>, 
										<<Num16:?LEN_DWORD, Num17:?LEN_DWORD, Num18:?LEN_DWORD>>,
										<<Num19:?LEN_DWORD, Num20:?LEN_DWORD, Num21:?LEN_DWORD>>,
										<<Num22:?LEN_DWORD, Num23:?LEN_DWORD, Num24:?LEN_DWORD>>,
										<<Num25:?LEN_DWORD, Num26:?LEN_DWORD>>]),
							Xor = vdr_data_parser:bxorbytelist(Content),
							list_to_binary([Content, Xor])
					end;
				true ->
					Content = list_to_binary([<<106:?LEN_DWORD, 0:?LEN_BYTE, 21:?LEN_BYTE>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>, 
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>, 
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>, 
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD>>]),
					Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
			end;
		_ ->
			Content = list_to_binary([<<106:?LEN_DWORD, 0:?LEN_BYTE, 21:?LEN_BYTE>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD, 0:?LEN_DWORD>>,
								<<0:?LEN_DWORD, 0:?LEN_DWORD>>]),
			Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

clear_link_info_reponse(_Req) ->
	%Res = ets:lookup(msgservertable, linkpid),
	%case Res of
	%	[{linkpid, LinkPid}] ->
	%		if
	%			LinkPid =/= undefined ->
	%				LinkPid ! {self(), clear}
	%		end
	%end,
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 22:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

read_db_chinese_reponse(_Req) ->
	[{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
	case DBPid of
        undefined ->
		    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 23:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
         _ ->
			Pid = self(),
			Res = <<"">>,
			Msg = <<"select * from device left join vehicle on vehicle.device_id=device.id where device.authen_code='YXIdIFocQPwZ'">>,
			Res1 = list_to_binary([Res, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res2 = list_to_binary([Res1, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res3 = list_to_binary([Res2, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res4 = list_to_binary([Res3, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res5 = list_to_binary([Res4, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res6 = list_to_binary([Res5, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res7 = list_to_binary([Res6, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res8 = list_to_binary([Res7, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res9 = list_to_binary([Res8, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res10 = list_to_binary([Res9, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res11 = list_to_binary([Res10, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res12 = list_to_binary([Res11, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res13 = list_to_binary([Res12, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res14 = list_to_binary([Res13, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res15 = list_to_binary([Res14, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res16 = list_to_binary([Res15, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res17 = list_to_binary([Res16, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res18 = list_to_binary([Res17, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res19 = list_to_binary([Res18, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res20 = list_to_binary([Res19, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res21 = list_to_binary([Res20, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res22 = list_to_binary([Res21, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res23 = list_to_binary([Res22, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res24 = list_to_binary([Res23, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res25 = list_to_binary([Res24, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res26 = list_to_binary([Res25, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res27 = list_to_binary([Res26, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res28 = list_to_binary([Res27, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res29 = list_to_binary([Res28, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res30 = list_to_binary([Res29, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Len = 2 + byte_size(Res30),
		    Content = list_to_binary([<<Len:?LEN_DWORD, 0:?LEN_BYTE, 23:?LEN_BYTE>>, Res30]),
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
    end.

read_db_chinese_init_reponse(_Req) ->
	[{dbpid, DBPid}] = ets:lookup(msgservertable, dbpid),
	case DBPid of
        undefined ->
		    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 24:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor]);
         _ ->
			Pid = self(),
			get_db_response(DBPid, Pid, <<"set names 'utf8'">>),
			Res = <<"">>,
			Msg = <<"select * from device left join vehicle on vehicle.device_id=device.id where device.authen_code='YXIdIFocQPwZ'">>,
			Res1 = list_to_binary([Res, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res2 = list_to_binary([Res1, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res3 = list_to_binary([Res2, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res4 = list_to_binary([Res3, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res5 = list_to_binary([Res4, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res6 = list_to_binary([Res5, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res7 = list_to_binary([Res6, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res8 = list_to_binary([Res7, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res9 = list_to_binary([Res8, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res10 = list_to_binary([Res9, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res11 = list_to_binary([Res10, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res12 = list_to_binary([Res11, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res13 = list_to_binary([Res12, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res14 = list_to_binary([Res13, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res15 = list_to_binary([Res14, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res16 = list_to_binary([Res15, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res17 = list_to_binary([Res16, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res18 = list_to_binary([Res17, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res19 = list_to_binary([Res18, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res20 = list_to_binary([Res19, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res21 = list_to_binary([Res20, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res22 = list_to_binary([Res21, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res23 = list_to_binary([Res22, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res24 = list_to_binary([Res23, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res25 = list_to_binary([Res24, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res26 = list_to_binary([Res25, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res27 = list_to_binary([Res26, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res28 = list_to_binary([Res27, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res29 = list_to_binary([Res28, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Res30 = list_to_binary([Res29, <<", ">>, get_db_response_record(DBPid, Pid, Msg, <<"vehicle">>, <<"code">>)]),
			Len = 2 + byte_size(Res30),
		    Content = list_to_binary([<<Len:?LEN_DWORD, 0:?LEN_BYTE, 24:?LEN_BYTE>>, Res30]),
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
    end.

get_db_response_record(DBPid, Pid, Msg, Table, Col) ->
	Record = get_db_response(DBPid, Pid, Msg),
	case vdr_handler:extract_db_resp(Record) of
        {ok, empty} ->
            <<"">>;
        {ok, [Rec]} ->
			{Table, Col, Code} =vdr_handler:get_record_field(Table, Rec, Col),
			Code
	end.
	
get_db_response(DBPid, Pid, Msg) ->
    DBPid ! {Pid, conn, Msg},
    receive
        {Pid, Result} ->
            Result
    end.

get_system_info_reponse(_Req) ->
	PortLimit = erlang:system_info(port_limit),
	PortCount = erlang:system_info(port_count),
	ProcLimit = erlang:system_info(process_limit),
	ProcCount = erlang:system_info(process_count),
	Memories = erlang:memory(),
	Total = find_Tuple_in_turple_list(Memories, total),
	Processes = find_Tuple_in_turple_list(Memories, processes),
	ProcessesUsed = find_Tuple_in_turple_list(Memories, processes_used),
	System = find_Tuple_in_turple_list(Memories, system),
	Atom = find_Tuple_in_turple_list(Memories, atom),
	AtomUsed = find_Tuple_in_turple_list(Memories, atom_used),
	Binary = find_Tuple_in_turple_list(Memories, binary),
	Code = find_Tuple_in_turple_list(Memories, code),
	Ets = find_Tuple_in_turple_list(Memories, ets),
	Maximum = find_Tuple_in_turple_list(Memories, maximum),
    Content = <<58:?LEN_DWORD, 0:?LEN_BYTE, 25:?LEN_BYTE,
				PortLimit:?LEN_DWORD, PortCount:?LEN_DWORD, ProcLimit:?LEN_DWORD,
				ProcCount:?LEN_DWORD, Total:?LEN_DWORD, Processes:?LEN_DWORD,
				ProcessesUsed:?LEN_DWORD, System:?LEN_DWORD, Atom:?LEN_DWORD,
				AtomUsed:?LEN_DWORD, Binary:?LEN_DWORD, Code:?LEN_DWORD,
				Ets:?LEN_DWORD, Maximum:?LEN_DWORD>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

find_Tuple_in_turple_list(TupleList, Key) when is_list(TupleList),
											   length(TupleList) > 0,
											   is_atom(Key) ->
	[H|T] = TupleList,
	IsTuple = erlang:is_tuple(H),
	TupleLen = erlang:tuple_size(H),
	if
		IsTuple == true andalso TupleLen == 2 ->
			{K, V} = H,
			if
				K == Key ->
					V;
				true ->
					find_Tuple_in_turple_list(T, Key)
			end;
		true ->
			find_Tuple_in_turple_list(T, Key)
	end;
find_Tuple_in_turple_list(_TupleList, _Key) ->
	0.

get_driver_count_response(State) ->
	DriverTablePid = State#monitem.driverpid,
	Pid = State#monitem.pid,
	DriverTablePid ! {Pid, count},
	receive
		{Pid, Count} ->
		    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 26:?LEN_BYTE, Count:?LEN_DWORD>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	after ?TIMEOUT_MON ->
		    Content = <<6:?LEN_DWORD, 0:?LEN_BYTE, 26:?LEN_BYTE, 0:?LEN_DWORD>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

set_vdr_log(Req, State) ->
    BS = bit_size(Req),
    <<ReqValue:BS>> = Req,
	%common:loginfo("ReqValue ~p", [ReqValue]),
	VDRLogPid = State#monitem.vdrlogpid,
	VDRLogPid ! {set, ReqValue},
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 27:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

clear_vdr_log(Req, State) ->
    BS = bit_size(Req),
    <<ReqValue:BS>> = Req,
	%common:loginfo("ReqValue ~p", [ReqValue]),
	VDRLogPid = State#monitem.vdrlogpid,
	VDRLogPid ! {clear, ReqValue},
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 28:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

reset_vdr_log(State) ->
	VDRLogPid = State#monitem.vdrlogpid,
	VDRLogPid ! reset,
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 29:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).

get_vdr_log(State) ->
	Pid = self(),
	VDRLogPid = State#monitem.vdrlogpid,
	VDRLogPid ! {Pid, get},
	receive
		{Pid, VDRList} ->
			%common:loginfo("VDRList ~p", [VDRList]),
			VDRListBin = convert_numbers_to_4_bytes_list(VDRList),
			Len = byte_size(VDRListBin),
		    Content = list_to_binary([<<(2+Len):?LEN_DWORD, 0:?LEN_BYTE, 30:?LEN_BYTE>>, VDRListBin]),
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	after ?TIMEOUT_MON ->
		    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 30:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.

convert_numbers_to_4_bytes_list(Numbers) when is_list(Numbers),
											  length(Numbers) > 0 ->
	[H|T] = Numbers,
	TBytes = convert_numbers_to_4_bytes_list(T),
	if
		TBytes == <<"">> ->
			list_to_binary([<<H:32>>]);
		true ->
			list_to_binary([<<H:32>>, TBytes])
	end;
convert_numbers_to_4_bytes_list(_Numbers) ->
	<<"">>.

get_vdr_online_count(State) ->
	Pid = self(),
	VDROnlinePid = State#monitem.vdronlinepid,
	VDROnlinePid ! {Pid, count},
	receive
		{Pid, OLList} ->
			OLListBin = compose_online_count(OLList),
			OLListBinSize = byte_size(OLListBin),
		    Content = list_to_binary([<<(2+OLListBinSize):?LEN_DWORD, 0:?LEN_BYTE, 31:?LEN_BYTE>>, OLListBin]),
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	after ?PROC_RESP_TIMEOUT ->
		    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 31:?LEN_BYTE>>,
		    Xor = vdr_data_parser:bxorbytelist(Content),
			list_to_binary([Content, Xor])
	end.		

compose_online_count(OLList) when is_list(OLList),
								  length(OLList) > 0 ->
	[H|T] = OLList,
	{VID, Count} = H,
	HBin=get_2_dword_from_online(VID, Count),
	TBin=compose_online_count(T),
	list_to_binary([HBin, TBin]);
compose_online_count(_OLList) ->
	<<>>.

get_2_dword_from_online(VID, Count) when is_integer(VID),
										 is_integer(Count) ->
	<<VID:32,Count:32>>;
get_2_dword_from_online(VID, Count) when is_binary(VID),
										 is_integer(Count) ->
	try
		VIDInt = binary_to_integer(VID),
		get_2_dword_from_online(VIDInt, Count)
	catch
		_:_ ->
			<<>>
	end;
get_2_dword_from_online(VID, Count) when is_binary(VID),
										 is_binary(Count) ->
	try
		VIDInt = binary_to_integer(VID),
		CountInt = binary_to_integer(Count),
		get_2_dword_from_online(VIDInt, CountInt)
	catch
		_:_ ->
			<<>>
	end;
get_2_dword_from_online(VID, Count) when is_integer(VID),
										 is_binary(Count) ->
	try
		CountInt = binary_to_integer(Count),
		get_2_dword_from_online(VID, CountInt)
	catch
		_:_ ->
			<<>>
	end;
get_2_dword_from_online(_VID, _Count) ->
	<<>>.

get_vdr_online(Req, State) ->
	Pid = self(),
	VDROnlinePid = State#monitem.vdronlinepid,
	IsBin = is_binary(Req),
	if
		IsBin == true ->
			try
				Int = binary_to_integer(Req),
				VDROnlinePid ! {Pid, get, Int},
				receive
					{Pid, DTList} ->
						DTListBin = compose_vdr_online_table(DTList),
						DTListBinSize = byte_size(DTListBin),
					    Content = list_to_binary([<<(2+DTListBinSize):?LEN_DWORD, 0:?LEN_BYTE, 32:?LEN_BYTE>>, DTListBin]),
					    Xor = vdr_data_parser:bxorbytelist(Content),
						list_to_binary([Content, Xor])
				after ?PROC_RESP_TIMEOUT ->
				    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 32:?LEN_BYTE>>,
				    Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
				end
			catch
				_:_ ->
				    Content1 = <<2:?LEN_DWORD, 0:?LEN_BYTE, 32:?LEN_BYTE>>,
				    Xor1 = vdr_data_parser:bxorbytelist(Content1),
					list_to_binary([Content1, Xor1])
			end;
		true ->
			IsInt = is_integer(Req),
			if
				IsInt == true ->
					VDROnlinePid ! {Pid, get, Req},
					receive
						{Pid, DTList} ->
							DTListBin = compose_vdr_online_table(DTList),
							DTListBinSize = byte_size(DTListBin),
						    Content = list_to_binary([<<(2+DTListBinSize):?LEN_DWORD, 0:?LEN_BYTE, 32:?LEN_BYTE>>, DTListBin]),
						    Xor = vdr_data_parser:bxorbytelist(Content),
							list_to_binary([Content, Xor])
					after ?PROC_RESP_TIMEOUT ->
					    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 32:?LEN_BYTE>>,
					    Xor = vdr_data_parser:bxorbytelist(Content),
						list_to_binary([Content, Xor])
					end;
				true ->
				    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 32:?LEN_BYTE>>,
				    Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
			end
	end.

compose_vdr_online_table(DTList) when is_list(DTList),
									  length(DTList) > 0 ->
	[H|T] = DTList,
	{_VID, {YY,MM,DD,Hh,Mm,Ss}} = H,
	YYNew = YY rem 100,
	HBin = <<YYNew:8,MM:8,DD:8,Hh:8,Mm:8,Ss:8>>,
	TBin=compose_vdr_online_table(T),
	list_to_binary([HBin, TBin]);
compose_vdr_online_table(_DTList) ->
	<<>>.

clear_vdr_online(Req, State) ->
	Pid = self(),
	VDROnlinePid = State#monitem.vdronlinepid,
	IsBin = is_binary(Req),
	if
		IsBin == true ->
			try
				Int = binary_to_integer(Req),
				VDROnlinePid ! {Pid, clear, Int},
			    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 33:?LEN_BYTE>>,
			    Xor = vdr_data_parser:bxorbytelist(Content),
				list_to_binary([Content, Xor])
			catch
				_:_ ->
				    Content0 = <<2:?LEN_DWORD, 0:?LEN_BYTE, 33:?LEN_BYTE>>,
				    Xor0 = vdr_data_parser:bxorbytelist(Content0),
					list_to_binary([Content0, Xor0])
			end;
		true ->
			IsInt = is_integer(Req),
			if
				IsInt == true ->
					VDROnlinePid ! {Pid, clear, Req},
				    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 33:?LEN_BYTE>>,
				    Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor]);
				true ->
				    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 33:?LEN_BYTE>>,
				    Xor = vdr_data_parser:bxorbytelist(Content),
					list_to_binary([Content, Xor])
			end
	end.

reset_vdr_online(State) ->
	VDROnlinePid = State#monitem.vdronlinepid,
	VDROnlinePid ! reset,
    Content = <<2:?LEN_DWORD, 0:?LEN_BYTE, 34:?LEN_BYTE>>,
    Xor = vdr_data_parser:bxorbytelist(Content),
	list_to_binary([Content, Xor]).
