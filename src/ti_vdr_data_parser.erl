%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_data_parser).

-include("ti_header.hrl").

-export([parse_data/3]).

%%%
%%% check 0x7d
%%%
%restore_data(Data) ->
%    Data.

%%%
%%% Parse the data from VDR
%%% Return :
%%%     {ok, Decoed, State}
%%%     {fail, [Resend FlowIndex List]}
%%%     error
%%%
parse_data(Socket, State, Data) ->
    % Display the data source IP
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo("Paring data from VDR IP : ~p~n", [Address]);
        {error, Explain} ->
            ti_common:loginfo("Parsing data from unknown VDR : ~p~n", [Explain])
    end,
    % Concrete jobs here
    try do_parse_data(Socket, State, Data) of
        {ok, Decoed, State} ->
            {ok, Decoed, State};
        {fail, [FlowNumber]} ->
            {fail, [FlowNumber]};
        error ->
            error
    catch
        error:Error ->
            ti_common:loginfo("ERROR : parsing data error : ~p~n", [Error]),
            error;
        throw:Throw ->
            ti_common:loginfo("ERROR : parsing data throw : ~p~n", [Throw]),
            error;
        exit:Exit ->
            ti_common:loginfo("ERROR : parsing data exit : ~p~n", [Exit]),
            error
    end.

%%%
%%% Internal usage for parse_data(Socket, State, Data)
%%% Return :
%%%     {ok, Decoded, State}
%%%     {fail, [Resend FlowIndex List]}
%%%     error
%%%
do_parse_data(_Socket, State, Data) ->
    NoParityLen = byte_size(Data) - 1,
    <<HeaderBody:NoParityLen,Parity/binary>>=Data,
    CalcParity = bxorbytelist(HeaderBody),
    if
        CalcParity == Parity ->
            RestoredData = restoremsg(State, Data),
            <<IDField:16,BodyPropField:16,_TelNumberField:48,FlowNumberField:16,TailField/binary>>=RestoredData,
            <<_ReservedField:2,PackageField:1,_CryptoTypeField:3,BodyLenField:10>> = BodyPropField,
            case PackageField of
                0 ->
                    Body = TailField,
                    ActBodyLen = byte_size(Body),
                    <<BodyLen:10>> = BodyLenField,
                    if
                        BodyLen == ActBodyLen ->
                            % Call ASN.1 parser here
                            Decoded = [],
                            {ok, Decoded, State};
                        BodyLen =/= ActBodyLen ->
                            % Ask VDR resend this msg
                            {fail, [FlowNumberField]}
                    end;
                1 ->
                    <<PackageInfoField:32,Body/binary>> = TailField,
                    ActBodyLen = byte_size(Body),
                    <<Total:16,Index:16>> = PackageInfoField,
                    if
                        Total =< 1 ->
                            {fail, [FlowNumberField]};
                        Total > 1 ->
                            if
                                Index > Total ->
                                    {fail, [FlowNumberField]};
                                Index =< Total ->
                                    <<BodyLen:10>> = BodyLenField,
                                    if
                                        BodyLen == ActBodyLen ->
                                            case combinemsgpacks(State, IDField, FlowNumberField, Total, Index, Body) of
                                                {complete, _BinMsg, NewState} ->
                                                    % Call ASN.1 parser here
                                                    Decoded = [],
                                                    {ok, Decoded, NewState};
                                                {notcomplete, NewState} ->
                                                    {ok, NewState}
                                            end;
                                        BodyLen =/= ActBodyLen ->
                                            % Ask VDR resend this msg
                                            {fail, [FlowNumberField]}
                                    end
                            end
                    end
            end;
        CalcParity =/= Parity ->
            ti_common:logerror("ERROR : calculated parity (~p) =/= data parity (~p) from ~p~n", [CalcParity, Parity, State#vdritem.addr]),
            error
    end.
    %VDRItem = ets:lookup(vdrtable, Socket),
    %Length = length(VDRItem),
    %case Length of
    %    1 ->
    %        % do concrete parse job here
    %        {ok, RestoredData};
    %    _ ->
    %        ti_common:logerror("vdrtable doesn't contain the vdritem.~n"),
    %        error
    %end.

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
%%% 0x7d0x1 -> ox7d & 0x7d0x2 -> 0x7e
%%%
restoremsg(State, Data) ->
    BinLength = length(Data),
    {BinHeader, BinRemain} = split_binary(Data, 1),
    {BinBody, BinTail} = split_binary(BinRemain, BinLength-2),
    case BinHeader of
        <<126>> ->
            % 126 is 0x7e
            case BinTail of
                <<126>> ->
                    Result = binary:replace(BinBody, <<125,1>>, <<125>>),
                    FinalResult = binary:replace(Result, <<125,2>>, <<126>>),
                    {ok, FinalResult};
                _ ->
                    ti_common:logerror("ERROR : wrong data tail (~p) from ~p~n",[BinTail, State#vdritem.addr]),
                    error
            end;
        _ ->
            ti_common:logerror("ERROR: wWrong data header (~p) from ~p~n",[BinHeader, State#vdritem.addr]),
            error
    end.

%%%
%%% Check whether received a complete msg packages
%%% State#vdritem.msg : [[ID0,FlowNum0,Total0,Index0,Data0],[ID1,FlowNum1,Total1,Index1,Data1],[ID2,FlowNum2,Total2,Index2,Data2],..
%%%
combinemsgpacks(State, ID, FlowNum, Total, Idx, Body) ->
    % Get all msg packages with the same ID
    MsgWithID = getmsgwithid(State#vdritem.msg,ID),        % [E || E <- State#vdritem.msg, [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = E, HID == ID ]
    % Get all msg packages without the same ID
    MsgWithoutID = getmsgwithoutid(State#vdritem.msg,ID),  % [E || E <- State#vdritem.msg, [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = E, HID =/= ID ]
    case MsgWithID of
        [] ->
            NewState = State#vdritem{msg=[[ID,FlowNum,Total,Idx,Body]|State#vdritem.msg]},
            {notcomplete,NewState};
        _ ->
            NewMsgWithID = [[ID,FlowNum,Total,Idx,Body]|delpackwithidx(MsgWithID,FlowNum,Total,Idx)],
            case checkmsg(NewMsgWithID, Total) of
                ok ->
                    Msg = composemsg(NewMsgWithID, Total),
                    [H|_T] = Msg,
                    [_ID,FlowNum,_Total,_Idx,_Body] = H,
                    case checkmsgflownum(Msg, FlowNum) of
                        ok ->
                            NewState = State#vdritem{msg=MsgWithoutID},
                            BinMsg = composerealmsg(Msg),
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
getmsgwithid(Msg, ID) ->
    case Msg of
        [] ->
            Msg;
        _ ->
            [H|T] = Msg,
            [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = H,
            if
                HID == ID ->
                    [H|getmsgwithid(T, ID)];
                HID =/= ID ->
                    getmsgwithid(T, ID)
            end
    end.

%%%
%%% Msg : [[ID0,FlowNum0,Total0,Index0,Data0],[ID1,FlowNum1,Total1,Index1,Data1],[ID2,FlowNum2,Total2,Index2,Data2],...
%%% This function is to created a new list with the ones whose IDn is NOT the same as ID.
%%%
getmsgwithoutid(Msg, ID) ->
    case Msg of
        [] ->
            Msg;
        _ ->
            [H|T] = Msg,
            [HID,_HFlowNum,_HTotal,_HIdx,_HBody] = H,
            if
                HID == ID ->
                    getmsgwithoutid(T, ID);
                HID =/= ID ->
                    [H|getmsgwithoutid(T, ID)]
            end
    end.

%%%
%%%
%%%
%delmsgpackreqbyid(Reqs, ID) ->
%    case Reqs of
%        [] ->
%            [];
%        _ ->
%            [H|T] = Reqs,
%            [HID,_HIdx] = H,
%            if
%                HID == ID ->
%                    delmsgpackreqbyid(T, ID);
%                HID =/= ID ->
%                    [H|delmsgpackreqbyid(T, ID)]
%            end
%    end.

%%%
%%% Remove msg package with the same Index from the msg packages
%%% Before calling this method, please first call getmsgwithid(Msg, ID) to get the msg packages with the ID.
%%%
delpackwithidx(Msg, FlowNum, Total, Idx) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [_HID,HFlowNum,HTotal,HIdx,_HBody] = H,
            if
                HFlowNum + (HTotal - HIdx) < FlowNum ->
                    % This is the 2nd msg and dicard the 1st one
                    delpackwithidx(T,FlowNum,Total,Idx);
                HFlowNum + (HTotal - HIdx) >= FlowNum ->
                    DiffTotal = HTotal - Total,
                    if
                        DiffTotal == 0 ->
                            if
                                Idx == HIdx ->
                                    delpackwithidx(T,FlowNum,Total,Idx);
                                Idx =/= HIdx ->
                                    [H,delpackwithidx(T,FlowNum,Total,Idx)]
                            end;
                        DiffTotal =/= 0 ->
                            % Take the new msg package as the standard
                            delpackwithidx(T,FlowNum,Total,Idx)
                    end
            end
    end.

%%%
%%% Internal usage for combinemsgpacks(State, ID, FlowNum, Total, Idx, Body)
%%% Check whether Packages includes all packages by checking the package index
%%%
checkmsg(Packages, Total) ->
    Len = length(Packages),
    if
        Len == Total ->
            case delnumfromnumlist(numberlist(Total), Packages) of
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
delnumfromnumlist(NumList, Packages) ->
    case Packages of
        [] ->
            NumList;
        _ ->
            [H|T] = Packages,
            [_ID,_FlowNum,_Total,Idx,_Body] = H,
            NewNumList = [E || E <- NumList, E =/= Idx],
            delnumfromnumlist(NewNumList, T)
    end.

%%%
%%% Internal usage for combinemsgpacks(State, ID, FlowNum, Total, Idx, Body)
%%% The caller will check the length of Packages first
%%%
composemsg(Packages, Total) ->
    if
        Total < 1 ->
            [];
        Total >= 1 ->
            [getpackbyidx(Packages, Total)|composemsg(Packages, Total-1)]
    end.

%%%
%%% Internal usag for composemsg(Packages, Total)
%%%
getpackbyidx(Packages, Idx) ->
    case Packages of
        [] ->
            [];
        _ ->
            [H|T] = Packages,
            [_ID,_FlowNum,_Total,HIdx,_Body] = H,
            if
                HIdx == Idx ->
                    {ok, H};
                HIdx =/= Idx ->
                    getpackbyidx(T, Idx)
            end
    end.

%%%
%%% Internal usage for combinemsgpacks(State, ID, FlowNum, Total, Idx, Body)
%%% Caller has make sure that Msg is not []
%%%
checkmsgflownum(Msg, FlowNum) ->
    case Msg of
        [] ->
            ok;
        _ ->
            [H|T] = Msg,
            [_ID,HFlowNum,_Total,_HIdx,_Body] = H,
            DiffFlowNum = HFlowNum - FlowNum,
            if
                DiffFlowNum == 1 ->
                    checkmsgflownum(T, FlowNum+1);
                DiffFlowNum =/= 1 ->
                    error
            end
    end.

%%%
%%%
%%%
composerealmsg(Msg) ->
    case Msg of
        [] ->
            [];
        _ ->
            [H|T] = Msg,
            [_ID,_FlowNum,_Total,_HIdx,Body] = H,
            [composerealmsg(T)|Body]
    end.

%%%
%%% Get the unreceived package indexes for vdritem.req
%%%
%getnotexistindexlist(Msg, ID, PackageTotal) ->
%    AllNumberList = numberlist(PackageTotal),
%    ExistNumberList = getexistnumberlist(Msg, []),
%    NotExistNumberList = removenumberfromlist(AllNumberList, ExistNumberList),
%    composemsgpackagereq(ID, NotExistNumberList).
%
%%%
%%%
%%%
%composemsgpackagereq(ID, NumberList) ->
%    case NumberList of
%        [] ->
%            [];
%        _ ->
%            [Header|Tail] = NumberList,
%            [[ID, Header]|composemsgpackagereq(ID, Tail)]
%    end.

%%%
%%% Internal usage,
%%% For example,
%%%     If Number == 3, returns [3,2,1],
%%%     If Number == 6, returns [6,5,4,3,2,1],
%%%
numberlist(Number) ->
    if
        Number > 0 ->
            [Number|numberlist(Number-1)];
        Number =< 0 ->
            []
    end.

%%%
%%% Internal usage
%%% Each msg package has a index, compose a list with all indexes from current msg packages
%%% Return [[ID0,FlowIndex0,PackageIndex0],[ID1,FlowIndex1,PackageIndex1],[ID2,FlowIndex2,PackageIndex2],...]
%%%
%getexistnumberlist(Msg, NumberList) ->
%    case Msg of
%        [] ->
%            NumberList;
%        _ ->
%            [[ID,FlowIndex,Data]|Tail] = Msg,
%            case getpackagetotalandindex(Data) of
%                error ->
%                    getexistnumberlist(Tail, NumberList);
%                {ok, _PackageTotal, PackageIndex} ->
%                    [[ID,FlowIndex,PackageIndex]|getexistnumberlist(Tail, NumberList)]
%            end
%    end.
%
%%%
%%% Internal usage
%%% Remove the specific number from the number list
%%% Return
%%%     if packagetotal == 6 and [[ID0,FlowIndex0,1],[ID1,FlowIndex1,3],[ID2,FlowIndex2,4]]
%%%     [6,5,2]
%%%
%removenumberfromlist(NumberList, RemoveNumberList) ->
%    case RemoveNumberList of
%        [] ->
%            NumberList;
%        _ ->
%            [Header|Tail] = RemoveNumberList,
%            [_ID,_FlowIndex,PackageIndex] = Header,
%            removenumberfromlist([E || E <- NumberList, E =/= PackageIndex], Tail)
%    end.
%
%%%
%%% For example,
%%%     NumberList = [6,5,4,3,2,1]
%%%     Msg : [[ID0,FlowIndex0,Data0],[ID1,FlowIndex1,Data1],[ID2,FlowIndex2,Data2],[ID3,FlowIndex3,Data3],...
%%% Get packagetotal and packageindex from Datan,
%%% Remove packageindex from NumberList.
%%% This function is to get the NOT existed msg package indexes.
%%%
%removeexistnumberfromlist(NumberList, Msg) ->
%    case Msg of
%        [] ->
%            NumberList;
%        _ ->
%            [[_ID,_FlowIndex,Data]|Tail] = Msg,
%            case getpackagetotalandindex(Data) of
%                error ->
%                    removeexistnumberfromlist(NumberList, Tail);
%                {ok, _PackageTotal, PackageIndex} ->
%                    NewNumberList = [E || E <- NumberList, E =/= PackageIndex],
%                    removeexistnumberfromlist(NewNumberList, Tail)
%            end
%    end.
%
%%%
%%% Return :
%%%     {ok, Total, Index}
%%%     error
%%%
%getpacktotalidx(Data) ->
%    try dogetpacktotalidx(Data) of
%        {ok, Total, Index} ->
%            {ok, Total, Index}
%    catch
%        error:Error ->
%            ti_common:loginfo("ERROR : get data package total & index error : ~p~n", [Error]),
%            error;
%        throw:Throw ->
%            ti_common:loginfo("ERROR : get data package total & index throw : ~p~n", [Throw]),
%            error;
%        exit:Exit ->
%            ti_common:loginfo("ERROR : get data package total & index exit : ~p~n", [Exit]),
%            error
%    end.
%
%%%
%%% internal usage
%%% {ok, Total, Index}
%%%
%dogetpacktotalidx(Data) ->
%    <<_ID:16,_BodyProp:16,_TelNum:48,_FlowNum:16,PackageInfo:32,_Body/binary>>=Data,
%    <<Total:16,Index:16>> = PackageInfo,
%    {ok, Total, Index}.
%
%%%
%%%
%%%
%dorestore0x7eand0x7d(Data) ->
%    BinLength = length(Data),
%    case BinLength of
%        0 ->
%            <<>>;
%        1 ->
%            Data;
%        _ ->
%            {BinFirst, BinLast} = split_binary(Data, 1),
%            case BinFirst of
%                <<125>> ->
%                    % 125 is 0x7d
%                    BinLastLength = length(BinLast),
%                    case BinLastLength of 
%                        1 ->
%                            case BinLast of
%                                <<1>> ->
%                                    <<125>>;
%                                <<2>> ->
%                                    <<126>>;
%                                _ ->
%                                    Data
%                            end;
%                        _ ->
%                            {BinLastFirst, BinLastLast} = split_binary(BinLast, 1),
%                            case BinLastFirst of
%                                <<1>> ->
%                                    list_to_binary([<<125>>, dorestore0x7eand0x7d(BinLastLast)]);
%                                <<2>> ->
%                                    list_to_binary([<<126>>, dorestore0x7eand0x7d(BinLastLast)]);
%                                _ ->
%                                    list_to_binary([list_to_binary([BinFirst, BinLastFirst]), dorestore0x7eand0x7d(BinLastLast)])
%                            end
%                    end;
%                _ ->
%                    list_to_binary([BinFirst, dorestore0x7eand0x7d(BinLast)])
%            end
%    end.
%
%%%
%%% Compose the data to VDR
%%%
%compose_data(Data) ->
%    Data.
%
%%%
%%%
%%%



