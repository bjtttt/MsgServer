%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(vdr_data_parser).

-include("header.hrl").

-export([process_data/2, bxorbytelist/1]).

%%%
%%% check 0x7d
%%%
%restore_data(Data) ->
%    Data.

%%%
%%% Parse the data from VDR
%%% Return :
%%%     {ok, HeadInfo, Res, State}
%%%     {ignore, HeadInfo, State}
%%%     {warning, HeadInfo, ErrorType, State}
%%%     {error, exception/formaterror/parityerror, State}
%%%
%%%     formaterror : Head/Tail is not 16#7e
%%%     parityerror :
%%%     warning     : error message/not supported/fail
%%%     ignore      : not complete message (maybe this state is not necessary)
%%%
process_data(State, Data) ->
    %DataDebug = <<126,2,0,0,46,1,86,121,16,51,112,0,14,0,0,0,0,0,0,0,17,0,0,0,0,0,0,0,0,0,0,0,0,0,0,19,3,20,0,64,34,1,4,0,0,0,0,2,2,0,0,3,2,0,0,4,2,0,0,42,126>>,
    try do_process_data(State, Data)
    catch
        _:Why ->
			[ST] = erlang:get_stacktrace(),
            common:logerr("Parsing VDR data exception : ~p~n~p~nStack trace :~n~p", [Why, Data, ST]),
            {error, exception, State}
    end.

%%%
%%% Internal usage for parse_data(Socket, State, Data)
%%% Return :
%%%     {ok, HeadInfo, Res, State}
%%%     {ignore, HeadInfo, State}
%%%     {warning, HeadInfo, ErrorType, State}
%%%     {error, formaterror/parityerror, State}
%%%
%%%     formaterror : Head/Tail is not 16#7e
%%%     parityerror :
%%%     warning     : error message/not supported/fail
%%%     ignore      : not complete message (maybe this state is not necessary)
%%%
%%% HeadInfo = {ID, MsgIdx, Tel, CryptoType}
%%%
%%% What is Decoded, still in design
%%%
do_process_data(State, Data) ->
    case restore_7d_7e_msg(State, Data) of
        {ok, RawData} ->
            NoParityLen = byte_size(RawData) - 1,
            {HeaderBody, Parity} = split_binary(RawData, NoParityLen),
            CalcParity = bxorbytelist(HeaderBody),
            if
                CalcParity == Parity ->
                    <<ID:16, Property:16, Tel:48, MsgIdx:16, Tail/binary>> = HeaderBody,
                    <<_Reserved:2, Pack:1, CryptoType:3, BodyLen:10>> = <<Property:16>>,
                    HeadInfo = {ID, MsgIdx, Tel, CryptoType},
                    case Pack of
                        0 ->
                            % Single package message
                            Body = Tail,
                            ActBodyLen = byte_size(Body),
                            if
                                BodyLen == ActBodyLen ->
                                    case vdr_data_processor:parse_msg_body(ID, Body) of
                                        {ok, Result} ->
                                            {ok, HeadInfo, Result, State};
                                        {error, msgerror} ->
                                            {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                        {error, unsupported} ->
                                            {warning, HeadInfo, ?P_GENRESP_NOTSUPPORT, State}
                                    end;
                                BodyLen =/= ActBodyLen ->
									common:send_stat_err(State, lenerr),
                                    common:logerror("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p", [MsgIdx, State#vdritem.addr, BodyLen, ActBodyLen]),
                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State}
                            end;
                        1 ->
                            % Multi package message
                            <<PackInfo:32,Body/binary>> = Tail,
                            ActBodyLen = byte_size(Body),
                            <<Total:16,Index:16>> = <<PackInfo:32>>,
                            if
                                Total =< 1 ->
									common:send_stat_err(State, packerr),
                                    common:logerror("Total error for msg (~p) from (~p) : ~p", [MsgIdx, State#vdritem.addr, Total]),
                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                Total > 1 ->
                                    if
                                        Index < 1 ->
											common:send_stat_err(State, packerr),
                                            common:logerror("Index error for msg (~p) from (~p) : (Index)~p", [MsgIdx, State#vdritem.addr, Index]),
                                            {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                        Index > Total ->
											common:send_stat_err(State, packerr),
                                            common:logerror("Index error for msg (~p) from (~p) : (Total)~p:(Index)~p", [MsgIdx, State#vdritem.addr, Total, Index]),
                                            {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                        Index =< Total ->
                                            if
                                                BodyLen == ActBodyLen ->
                                                    case combine_msg_packs(State, ID, MsgIdx, Total, Index, Body) of
                                                        {complete, Msg, NewState} ->
															common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nMsg packages is combined successfully (ID :~p)", 
																		   [State#vdritem.addr,
																			State#vdritem.id,
																			State#vdritem.serialno,
																			State#vdritem.auth,
																			State#vdritem.vehicleid,
																			State#vdritem.vehiclecode, ID]),
                                                            case vdr_data_processor:parse_msg_body(ID, Msg) of
                                                                {ok, Result} ->
                                                                    {ok, HeadInfo, Result, NewState};
                                                                {warning, msgerror} ->
                                                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, NewState};
                                                                {warning, unsupported} ->
                                                                    {warning, HeadInfo, ?P_GENRESP_NOTSUPPORT, NewState}
                                                            end;
                                                        {notcomplete, NewState} ->
                                                            {ignore, HeadInfo, NewState}
                                                    end;
                                                BodyLen =/= ActBodyLen ->
													common:send_stat_err(State, lenerr),
                                                    common:logerror("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p", [MsgIdx, State#vdritem.addr, BodyLen, ActBodyLen]),
                                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State}
                                            end
                                    end
                            end
                    end;
                CalcParity =/= Parity ->
					common:send_stat_err(State, parerr),
                    common:logerror("Parity error (calculated)~p:(data)~p from ~p", [CalcParity, Parity, State#vdritem.addr]),
                    {error, parityerror, State}
            end;
        error ->
			common:send_stat_err(State, resterr),
            {error, formaterror, State}
    end.

%%%
%%% XOR a binary list
%%% The caller must make sure of the length of data must be larger than or equal to 1
%%% Input : Data is a binary list
%%%
bxorbytelist(Data) ->
    Len = byte_size(Data),
    case Len of
        1 ->
            Data;
        2 ->
            <<HInt:8,TInt:8>> = Data,
            Res = HInt bxor TInt,
            <<Res>>;
        _ ->
            <<HInt:8, T/binary>> = Data,
            <<TInt:8>> = bxorbytelist(T),
            Res = HInt bxor TInt,
            <<Res>>
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
            common:logerror("Wrong data head/tail from ~p~n: (Head)~p / (Tail)~p",[State#vdritem.addr, Head, Tail]),
            error
    end.

%%%
%%% Check whether received a complete msg packages
%%% State#vdritem.msg : [[ID0,MsgIdx0,Total0,Index0,Data0],[ID1,MsgIdx1,Total1,Index1,Data1],[ID2,MsgIdx2,Total2,Index2,Data2],..
%%%
combine_msg_packs(State, ID, MsgIdx, Total, Idx, Body) ->
    % Get all msg packages with the same ID
	StoredMsg = State#vdritem.msg,
    MsgWithID = get_msg_with_id(StoredMsg, ID),        % [E || E <- State#vdritem.msg, [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = E, HID == ID ]
    % Get all msg packages without the same ID
    MsgWithoutID = get_msg_without_id(StoredMsg, ID),  % [E || E <- State#vdritem.msg, [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = E, HID =/= ID ]
    {_LastID, MsgPackages} = State#vdritem.msgpackages,
    case MsgWithID of
        [] ->
			MergedList = lists:merge([[ID,MsgIdx,Total,Idx,Body]], StoredMsg),
            NewMsgPackages = update_msg_packs(MsgPackages, ID, get_missing_pack_msgidxs([[ID,MsgIdx,Total,Idx,Body]])),
			common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 0 : ~p", 
						   [State#vdritem.addr,
							State#vdritem.id,
							State#vdritem.serialno,
							State#vdritem.auth,
							State#vdritem.vehicleid,
							State#vdritem.vehiclecode,
							NewMsgPackages]),
    		NewState = State#vdritem{msg=MergedList, msgpackages={ID, NewMsgPackages}},
			{notcomplete, NewState};
    	_ ->
			case check_ignored_msg(MsgWithID, MsgIdx, Total, Idx) of
				new ->
					NewMsgWithID = [[ID, MsgIdx, Total, Idx, Body]],
		            case check_msg(NewMsgWithID, Total) of
		                ok ->
		                    Msg = compose_msg(NewMsgWithID, Total),
		                    [H|_T] = Msg,
		                    [_ID, FirstMsgIdx, _Total, _Idx, _Body] = H,
		                    case check_msg_idx(Msg, FirstMsgIdx) of
		                        ok ->
		                            NewState = State#vdritem{msg=MsgWithoutID},
		                            BinMsg = compose_real_msg(Msg),
                                    NewMsgPackages = remove_msgidx_with_id(MsgPackages, ID),
									common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 1 : ~p", 
												   [State#vdritem.addr,
													State#vdritem.id,
													State#vdritem.serialno,
													State#vdritem.auth,
													State#vdritem.vehicleid,
													State#vdritem.vehiclecode,
													NewMsgPackages]),
		                            {complete, BinMsg, NewState#vdritem{msgpackages={-1, NewMsgPackages}}};
		                        error ->
									MergedList = lists:merge(NewMsgWithID, MsgWithoutID),
                                    NewMsgPackages = update_msg_packs(MsgPackages, ID, get_missing_pack_msgidxs(NewMsgWithID)),
									common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 2 : ~p", 
												   [State#vdritem.addr,
													State#vdritem.id,
													State#vdritem.serialno,
													State#vdritem.auth,
													State#vdritem.vehicleid,
													State#vdritem.vehiclecode,
													NewMsgPackages]),
		                            NewState = State#vdritem{msg=MergedList, msgpackages={ID, NewMsgPackages}},
		                            {notcomplete, NewState}
		                    end;
		                error ->
							MergedList = lists:merge(NewMsgWithID, MsgWithoutID),
                            NewMsgPackages = update_msg_packs(MsgPackages, ID, get_missing_pack_msgidxs(NewMsgWithID)),
							common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 3 : ~p", 
										   [State#vdritem.addr,
											State#vdritem.id,
											State#vdritem.serialno,
											State#vdritem.auth,
											State#vdritem.vehicleid,
											State#vdritem.vehiclecode,
											NewMsgPackages]),
		                    NewState = State#vdritem{msg=MergedList, msgpackages={ID, NewMsgPackages}},
		                    {notcomplete, NewState}
		            end;
				false ->
					DelPack = del_pack_with_idx(MsgWithID, MsgIdx, Total, Idx),
				    NewMsgWithID = lists:merge([[ID, MsgIdx, Total, Idx, Body]], DelPack),
		            case check_msg(NewMsgWithID, Total) of
		                ok ->
		                    Msg = compose_msg(NewMsgWithID, Total),
		                    [H|_T] = Msg,
		                    [_ID, FirstMsgIdx, _Total, _Idx, _Body] = H,
		                    case check_msg_idx(Msg, FirstMsgIdx) of
		                        ok ->
		                            NewState = State#vdritem{msg=MsgWithoutID},
		                            BinMsg = compose_real_msg(Msg),
                                    NewMsgPackages = remove_msgidx_with_id(MsgPackages, ID),
									common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 4 : ~p", 
												   [State#vdritem.addr,
													State#vdritem.id,
													State#vdritem.serialno,
													State#vdritem.auth,
													State#vdritem.vehicleid,
													State#vdritem.vehiclecode,
													NewMsgPackages]),
		                            {complete, BinMsg, NewState#vdritem{msgpackages={-1, NewMsgPackages}}};
		                        error ->
									MergedList = lists:merge(NewMsgWithID, MsgWithoutID),
                                    NewMsgPackages = update_msg_packs(MsgPackages, ID, get_missing_pack_msgidxs(NewMsgWithID)),
									common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 5 : ~p", 
												   [State#vdritem.addr,
													State#vdritem.id,
													State#vdritem.serialno,
													State#vdritem.auth,
													State#vdritem.vehicleid,
													State#vdritem.vehiclecode,
													NewMsgPackages]),
		                            NewState = State#vdritem{msg=MergedList, msgpackages={ID, NewMsgPackages}},
		                            {notcomplete, NewState}
		                    end;
		                error ->
							MergedList = lists:merge(NewMsgWithID, MsgWithoutID),
                            NewMsgPackages = update_msg_packs(MsgPackages, ID, get_missing_pack_msgidxs(NewMsgWithID)),
							common:loginfo("VDR (~p) (id:~p, serialno:~p, authen_code:~p, vehicleid:~p, vehiclecode:~p)~nNew msg packages 6 : ~p", 
										   [State#vdritem.addr,
											State#vdritem.id,
											State#vdritem.serialno,
											State#vdritem.auth,
											State#vdritem.vehicleid,
											State#vdritem.vehiclecode,
											NewMsgPackages]),
		                    NewState = State#vdritem{msg=MergedList, msgpackages={ID, NewMsgPackages}},
		                    {notcomplete, NewState}
		            end;
				_ ->
					ok
			end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MsgPacks 	: [[ID0, FirstMsgIdx0, MsgIdxList0], [ID0, FirstMsgIdx0, MsgIdxList0], [ID0, FirstMsgIdx0, MsgIdxList0], ...]
% ID		: 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
remove_msgidx_with_id(MsgPacks, ID) when is_list(MsgPacks),
									     length(MsgPacks),
									     is_integer(ID),
                                         ID > 0 ->
    [H|T] = MsgPacks,
    [HID, _HFirstMsgIdx, _HMsgIdxs] = H,
    if
        HID == ID ->
            T;
        true ->
			case T of
				[] ->
					[H];
				_ ->
            		lists:merge([H], remove_msgidx_with_id(T, ID))
			end
    end;
remove_msgidx_with_id(_MsgPacks, _ID) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MsgPacks	: [[ID0, FirstMsgIdx0, MsgIdxs0], [ID1, FirstMsgIdx1, MsgIdxs1], [ID2, FirstMsgIdx2, MsgIdxs2], ...]
% ID		:
% MsgIdxs	: [MsgIdx0, MsgIdx1, MsgIdx2, ...] --- It should be the output of get_missing_pack_msgidxs(MsgWithID)
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
update_msg_packs(MsgPacks, ID, MsgIdxs) when is_list(MsgPacks),
                                             length(MsgPacks) > 0,
                                             is_integer(ID),
                                             ID > 0,
											 is_list(MsgIdxs),
											 length(MsgIdxs) > 0 ->
    [H|T] = MsgPacks,
    [HID, HFirstMsgIdx, _HMsgIdxs] = H,
	if
		HID == ID ->
			case MsgIdxs of
				none ->
					T;
				_ ->
					lists:merge([[ID, HFirstMsgIdx, MsgIdxs]], T)
			end;
		true ->
			lists:merge([[H]], update_msg_packs(T, ID, MsgIdxs))
	end;
update_msg_packs(MsgPacks, _ID, _MsgIdxs) ->
	MsgPacks.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Parameter
% MsgWithID	: [[ID0, MsgIdx0, Total0, Idx0, Body0], [ID1, MsgIdx1, Total1, Idx1, Body1], [ID2, MsgIdx2, Total2, Idx2, Body2], ...]
%
% Output
% {FirstMsgIdx, [MsgIdxn0, MsgIdxn1, MsgIdxn2, ...]}
%		MsgIdxnn is not in MsgWithID
% none
%		it means it is the 1st message package
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_missing_pack_msgidxs(MsgWithID) when is_list(MsgWithID),
                                         length(MsgWithID) > 0 ->
    Last = lists:last(MsgWithID),
    [_ID, LMsgIdx, LTotal, LIdx, _Body] = Last,
    FirstMsgIdx = LMsgIdx - (LTotal - LIdx),
    if
        LIdx == 1 ->
            none;
        true ->
            MissingIdxs = del_num_from_num_list([E || E <- lists:seq(1, LIdx)], MsgWithID),
            {FirstMsgIdx, calc_missing_pack_msgidxs(MissingIdxs, LMsgIdx, LIdx)}
    end;
get_missing_pack_msgidxs(_MsgWithID) ->
    none.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
calc_missing_pack_msgidxs(MissingIdxs, LastMsgIdx, LastIdx) when is_list(MissingIdxs),
                                                                 length(MissingIdxs) > 0,
                                                                 is_integer(LastMsgIdx),
                                                                 LastMsgIdx > 0,
                                                                 is_integer(LastIdx),
                                                                 LastIdx > 0 ->
    [H|T] = MissingIdxs,
    MissingMsgIdx = LastMsgIdx - (LastIdx - H),
    lists:merge([MissingMsgIdx], calc_missing_pack_msgidxs(T, LastMsgIdx, LastIdx));
calc_missing_pack_msgidxs(_MissingIdxs, _LastMsgIdx, _LastIdx) ->
    [].

check_ignored_msg(MsgWithID, MsgIdx, Total, Idx) when is_list(MsgWithID),
													  length(MsgWithID) > 0,
													  is_integer(MsgIdx),
													  is_integer(Total),
													  is_integer(Idx),
													  Total >= Idx ->
	[H|_T] = MsgWithID,
	[_ID, HMsgIdx, HTotal, HIdx, _Body] = H,
	common:loginfo("Header msg : MsgIdx ~p, Total ~p, Index ~p~nReceived msg : MsgIdx ~p, Total ~p, Index ~p",
				   [HMsgIdx, HTotal, HIdx, MsgIdx, Total, Idx]),
	if
		HTotal =/= Total ->
			true;
		true ->
			if
				HMsgIdx > MsgIdx ->
                    Diff0 = HMsgIdx - MsgIdx,
                    if
                        Diff0 >= HTotal ->
                            true;
                        true ->
        					if
        						HIdx > Idx ->
        							Diff1 = HIdx - Idx,
        							if
        								Diff0 =/= Diff1 ->
        									true;
        								true ->
        									false
        							end;
        						true ->
        							true
                            end
					end;
				HMsgIdx == MsgIdx ->
					true;
				HMsgIdx < MsgIdx ->
                    Diff0 = MsgIdx - HMsgIdx,
                    if
                        Diff0 >= HTotal ->
                            new;
                        true ->
        					if
        						HIdx < Idx ->
        							Diff1 = Idx - HIdx,
        							if
        								Diff0 =/= Diff1 ->
        									new;
        								true ->
        									false
        							end;
        						true ->
        							true
        					end
                    end
			end
	end.

%%%
%%% Msg : [[ID0,FlowNum0,Total0,Index0,Data0],[ID1,FlowNum1,Total1,Index1,Data1],[ID2,FlowNum2,Total2,Index2,Data2],...
%%% This function is to created a new list with the ones whose IDn is the same as ID.
%%%
get_msg_with_id(Msg, ID) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [HID,_HMsgIdx,_HTotal,_HIdx,_HBody] = H,
            if
                HID == ID ->
                    [H|get_msg_with_id(T, ID)];
                HID =/= ID ->
                    get_msg_with_id(T, ID)
            end
    end.

%%%
%%% Msg : [[ID0,FlowNum0,Total0,Index0,Data0],[ID1,FlowNum1,Total1,Index1,Data1],[ID2,FlowNum2,Total2,Index2,Data2],...
%%% This function is to created a new list with the ones whose IDn is NOT the same as ID.
%%%
get_msg_without_id(Msg, ID) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [HID,_HMsgIdx,_HTotal,_HIdx,_HBody] = H,
            if
                HID == ID ->
                    get_msg_without_id(T, ID);
                HID =/= ID ->
                    [H|get_msg_without_id(T, ID)]
            end
    end.

%%%
%%% Remove msg package with the same Index from the msg packages
%%% Before calling this method, please first call get_msg_with_id(Msg, ID) to get the msg packages with the ID.
%%%
del_pack_with_idx(Msg, MsgIdx, Total, Idx) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [_HID, HMsgIdx, HTotal, HIdx, _HBody] = H,
            if
                HMsgIdx + (HTotal - HIdx) < MsgIdx ->
                    % This is the 2nd msg and discard all the 1st ones
                    del_pack_with_idx(T, MsgIdx, Total, Idx);
                HMsgIdx + (HTotal - HIdx) >= MsgIdx ->
                    DiffTotal = HTotal - Total,
                    if
                        DiffTotal == 0 ->
                            if
                                Idx == HIdx ->
                                    del_pack_with_idx(T, MsgIdx, Total, Idx);
                                Idx =/= HIdx ->
                                    lists:merge([H], del_pack_with_idx(T, MsgIdx, Total, Idx))
                            end;
                        DiffTotal =/= 0 ->
                            % Take the new msg package as the standard
                            del_pack_with_idx(T, MsgIdx, Total, Idx)
                    end
            end
    end.

%%%
%%% Internal usage for combinemsgpacks(State, ID, FlowNum, Total, Idx, Body)
%%% Check whether Packages includes all packages by checking the package index
%%%
check_msg(Packages, Total) ->
    Len = length(Packages),
    if
        Len == Total ->
            case del_num_from_num_list([E || E <- lists:seq(1, Total)], Packages) of
                [] ->
                    ok;
                _ ->
                    error
            end;
        Len =/= Total ->
			common:logerror("Check message error : Packages length ~p =/= Total ~p", [Len, Total]),
            error
    end.

%%%
%%% Internal usage for checkmsg(Packages, Total)
%%% Remove the package index from the complete package index list
%%% Return the missing package index list
%%%
del_num_from_num_list(NumList, Packages) ->
	common:loginfo("Delete number from number list : current number list ~p", [NumList]),
    case Packages of
        [] ->
            NumList;
        _ ->
            [H|T] = Packages,
            [_ID, _MsgIdx, _Total, Idx, _Body] = H,
            NewNumList = [E || E <- NumList, E =/= Idx],
			common:loginfo("Delete number from number list : new number list ~p without ~p", [NewNumList, Idx]),
            del_num_from_num_list(NewNumList, T)
    end.

%%%
%%% Internal usage for combinemsgpacks(State, ID, FlowNum, Total, Idx, Body)
%%% The caller will check the length of Packages first
%%%
compose_msg(Packages, Total) ->
    if
        Total < 1 ->
            [];
        Total >= 1 ->
            lists:merge([get_package_by_idx(Packages, Total)], compose_msg(Packages, Total-1))
    end.

%%%
%%% Internal usag for composemsg(Packages, Total)
%%%
get_package_by_idx(Packages, Idx) ->
    case Packages of
        [] ->
            [];
        _ ->
            [H|T] = Packages,
            [_ID, _MsgIdx, _Total, HIdx, _Body] = H,
            if
                HIdx == Idx ->
                    H;
                HIdx =/= Idx ->
                    get_package_by_idx(T, Idx)
            end
    end.

%%%
%%% Internal usage for combine_msg_packs(State, ID, FlowNum, Total, Idx, Body)
%%% Caller has make sure that Msg is not []
%%%
check_msg_idx(Msg, MsgIdx) ->
    case Msg of
        [] ->
            ok;
        _ ->
            [H|T] = Msg,
            [_ID, HMsgIdx, _Total, _HIdx, _Body] = H,
            DiffMsgIdx = HMsgIdx - MsgIdx,
            if
                DiffMsgIdx == 0 ->
                    check_msg_idx(T, MsgIdx+1);
                DiffMsgIdx =/= 0 ->
                    error
            end
    end.

%%%
%%%
%%%
compose_real_msg(Msges) when is_list(Msges),
							 length(Msges) > 0 ->
    [H|T] = Msges,
    [_ID,_MsgIdx,_Total,_HIdx,Body] = H,
    list_to_binary([Body, compose_real_msg(T)]);
compose_real_msg(_Msges) ->
	<<>>.


