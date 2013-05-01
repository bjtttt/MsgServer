%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(vdr_data_parser).

-include("ti_header.hrl").

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
    try do_process_data(State, Data)
    catch
        _:Why ->
            ti_common:loginfo("Parsing VDR data exception : ~p~n", [Why]),
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
                                    ti_common:logerror("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p~n", [MsgIdx, State#vdritem.addr, BodyLen, ActBodyLen]),
                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State}
                            end;
                        1 ->
                            % Multi package message
                            <<PackInfo:32,Body/binary>> = Tail,
                            ActBodyLen = byte_size(Body),
                            <<Total:16,Index:16>> = <<PackInfo:32>>,
                            if
                                Total =< 1 ->
                                    ti_common:logerror("Total error for msg (~p) from (~p) : ~p~n", [MsgIdx, State#vdritem.addr, Total]),
                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                Total > 1 ->
                                    if
                                        Index < 1 ->
                                            ti_common:logerror("Index error for msg (~p) from (~p) : (Index)~p~n", [MsgIdx, State#vdritem.addr, Index]),
                                            {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                        Index > Total ->
                                            ti_common:logerror("Index error for msg (~p) from (~p) : (Total)~p:(Index)~p~n", [MsgIdx, State#vdritem.addr, Total, Index]),
                                            {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                        Index =< Total ->
                                            if
                                                BodyLen == ActBodyLen ->
                                                    case combine_msg_packs(State, ID, MsgIdx, Total, Index, Body) of
                                                        {complete, Msg, NewState} ->
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
                                                    ti_common:logerror("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p~n", [MsgIdx, State#vdritem.addr, BodyLen, ActBodyLen]),
                                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State}
                                            end
                                    end
                            end
                    end;
                CalcParity =/= Parity ->
                    ti_common:logerror("Parity error (calculated)~p:(data)~p from ~p~n", [CalcParity, Parity, State#vdritem.addr]),
                    {error, parityerror, State}
            end;
        error ->
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
            Result = binary:replace(Body, <<125,1>>, <<125>>, [global]),
            FinalResult = binary:replace(Result, <<125,2>>, <<126>>, [global]),
            {ok, FinalResult};
        true ->
            ti_common:logerror("Wrong data head/tail from ~p~n: (Head)~p / (Tail)~p",[State#vdritem.addr, Head, Tail]),
            error
    end.

%%%
%%% Check whether received a complete msg packages
%%% State#vdritem.msg : [[ID0,MsgIdx0,Total0,Index0,Data0],[ID1,MsgIdx1,Total1,Index1,Data1],[ID2,MsgIdx2,Total2,Index2,Data2],..
%%%
combine_msg_packs(State, ID, MsgIdx, Total, Idx, Body) ->
    % Get all msg packages with the same ID
    MsgWithID = get_msg_with_id(State#vdritem.msg, ID),        % [E || E <- State#vdritem.msg, [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = E, HID == ID ]
    % Get all msg packages without the same ID
    MsgWithoutID = get_msg_without_id(State#vdritem.msg, ID),  % [E || E <- State#vdritem.msg, [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = E, HID =/= ID ]
    case MsgWithID of
        [] ->
            NewState = State#vdritem{msg=[[ID,MsgIdx,Total,Idx,Body]|State#vdritem.msg]},
            {notcomplete, NewState};
        _ ->
            NewMsgWithID = [[ID, MsgIdx, Total, Idx, Body]|del_pack_with_idx(MsgWithID, MsgIdx, Total, Idx)],
            case check_msg(NewMsgWithID, Total) of
                ok ->
                    Msg = compose_msg(NewMsgWithID, Total),
                    [H|_T] = Msg,
                    [_ID, MsgIdx, _Total, _Idx, _Body] = H,
                    case check_msg_idx(Msg, MsgIdx) of
                        ok ->
                            NewState = State#vdritem{msg=MsgWithoutID},
                            BinMsg = compose_real_msg(Msg),
                            {complete, BinMsg, NewState};
                        error ->
                            NewState = State#vdritem{msg=[NewMsgWithID|MsgWithoutID]},
                            {notcomplete, NewState}
                    end;
                error ->
                    NewState = State#vdritem{msg=[NewMsgWithID|MsgWithoutID]},
                    {notcomplete, NewState}
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
                                    [H, del_pack_with_idx(T, MsgIdx, Total, Idx)]
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
            error
    end.

%%%
%%% Internal usage for checkmsg(Packages, Total)
%%% Remove the package index from the complete package index list
%%% Return the missing package index list
%%%
del_num_from_num_list(NumList, Packages) ->
    case Packages of
        [] ->
            NumList;
        _ ->
            [H|T] = Packages,
            [_ID, _MsgIdx, _Total, Idx, _Body] = H,
            NewNumList = [E || E <- NumList, E =/= Idx],
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
            [get_package_by_idx(Packages, Total)|compose_msg(Packages, Total-1)]
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
                    {ok, H};
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
compose_real_msg(Msg) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [_ID,_MsgIdx,_Total,_HIdx,Body] = H,
            list_to_binary([compose_real_msg(T)|Body])
    end.


