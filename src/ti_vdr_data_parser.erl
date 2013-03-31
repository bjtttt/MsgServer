%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_data_parser).

-include("ti_header.hrl").

-export([process_data/3]).

%%%
%%% check 0x7d
%%%
%restore_data(Data) ->
%    Data.

%%%
%%% Parse the data from VDR
%%% Return :
%%%     {ok, {Resp, State}, Result}
%%%     {fail, {Resp, State}}
%%%     {error, State}
%%%
%%% Still in design
%%%
process_data(Socket, State, Data) ->
    try do_process_data(Socket, State, Data) of
        {ok, {Resp, State}, Result} ->
            {ok, {Resp, State}, Result};
        {fail, {Resp, State}} ->
            {fail, {Resp, State}};
        {error, State} ->
            {error, State}
    catch
        error:Error ->
            ti_common:loginfo("ERROR : parsing data error : ~p~n", [Error]),
            {error, State};
        throw:Throw ->
            ti_common:loginfo("ERROR : parsing data throw : ~p~n", [Throw]),
            {error, State};
        exit:Exit ->
            ti_common:loginfo("ERROR : parsing data exit : ~p~n", [Exit]),
            {error, State}
    end.

%%%
%%% Internal usage for parse_data(Socket, State, Data)
%%% Return :
%%%     {ok, State}                 % No response to VDR
%%%     {ok, Resp, State}           % Response to VDR
%%%     {fail, Resp}                % Failure response to VDR
%%%     {ignore, Resp, State}       % Keep current package with response to VDR
%%%     {error, State}
%%%
%%% What is Decoded, still in design
%%%
do_process_data(_Socket, State, Data) ->
    RawData = restoremsg(State, Data),
    NoParityLen = byte_size(RawData) - 1,
    <<HeaderBody:NoParityLen,Parity/binary>> = RawData,
    CalcParity = bxorbytelist(HeaderBody),
    if
        CalcParity == Parity ->
            <<ID:16,BodyProp:16,TelNum:48,FlowNum:16,Tail/binary>>=HeaderBody,
            <<_Reserved:2,Pack:1,CryptoType:3,BodyLen:10>> = BodyProp,
            case Pack of
                0 ->
                    % Single package message
                    Body = Tail,
                    ActBodyLen = byte_size(Body),
                    if
                        BodyLen == ActBodyLen ->
                            case ti_vdr_msg_body_processor:parse_msg_body(ID, Body) of
                                {ok, Res} ->
                                    case ID of
                                        1 ->            % 0x0001
                                            {ResFlowNum, _PlatformID, _Result} = Res,
                                            Msg2VDR = State#vdritem.msg2vdr,
                                            NewMsg2VDR = ti_common:removemsgfromlistbyflownum(ResFlowNum, Msg2VDR),
                                            {ok, State#vdritem{msg2vdr=NewMsg2VDR}};
                                        2 ->            % 0x0002
                                            Resp = ti_vdr_msg_body_processor:create_p_genresp(FlowNum, ID, ?P_GENRESP_OK),
                                            {ok, Resp, State};
                                        _ ->
                                            {ok, State}
                                    end;
                                error ->
                                    error
                            end;
                        BodyLen =/= ActBodyLen ->
                            ti_common:logerror("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p~n", [FlowNum, State#vdritem.addr, BodyLen, ActBodyLen]),
                            {fail, createresp(ID, CryptoType, TelNum, FlowNum, 2, State)}
                    end;
                1 ->
                    % Multi package message
                    <<PackInfo:32,Body/binary>> = Tail,
                    ActBodyLen = byte_size(Body),
                    <<Total:16,Index:16>> = PackInfo,
                    if
                        Total =< 1 ->
                            ti_common:logerror("Total error for msg (~p) from (~p) : ~p~n", [FlowNum, State#vdritem.addr, Total]),
                            {fail, createresp(ID, CryptoType, TelNum, FlowNum, 2, State)};
                        Total > 1 ->
                            if
                                Index > Total ->
                                    ti_common:logerror("Index error for msg (~p) from (~p) : (Total)~p:(Index)~p~n", [FlowNum, State#vdritem.addr, Total, Index]),
                                    {fail, createresp(ID, CryptoType, TelNum, FlowNum, 2, State)};
                                Index =< Total ->
                                    if
                                        BodyLen == ActBodyLen ->
                                            case combinemsgpacks(State, ID, FlowNum, Total, Index, Body) of
                                                {complete, Msg, NewState} ->
                                                    case ti_vdr_msg_body_processor:parse_msg_body(ID, Body) of
                                                        {ok, Res} ->
                                                            {ok, Res};
                                                        error ->
                                                            error
                                                    end;
                                                {notcomplete, NewState} ->
                                                    {ok, createresp(ID, CryptoType, TelNum, FlowNum, 0, NewState)}
                                            end;
                                        BodyLen =/= ActBodyLen ->
                                            ti_common:logerror("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p~n", [FlowNum, State#vdritem.addr, BodyLen, ActBodyLen]),
                                            {fail, createresp(ID, CryptoType, TelNum, FlowNum, 2, State)}
                                    end
                            end
                    end
            end;
        CalcParity =/= Parity ->
            ti_common:logerror("Parity error (calculated)~p:(data)~p from ~p~n", [CalcParity, Parity, State#vdritem.addr]),
            {error, State}
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
%%% 0x7d0x1 -> 0x7d & 0x7d0x2 -> 0x7e
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
                    Result = binary:replace(BinBody, <<125,1>>, <<125>>, [global]),
                    FinalResult = binary:replace(Result, <<125,2>>, <<126>>, [global]),
                    {ok, FinalResult};
                _ ->
                    ti_common:logerror("Wrong data tail (~p) from ~p~n",[BinTail, State#vdritem.addr]),
                    error
            end;
        _ ->
            ti_common:logerror("Wrong data header (~p) from ~p~n",[BinHeader, State#vdritem.addr]),
            error
    end.

%%%
%%% Compose body, header and parity
%%% Calculate XOR value
%%% 0x7d -> 0x7d0x1 & 0x7e -> 0x7d0x2
%%%
%%% return {Response, NewState}
%%%
createresp(ID, CryptoType, TelNum, FlowNum, Result, State) ->
    RespFlowNum = State#vdritem.msgflownum,
    Body = <<FlowNum:16, ID:16, Result:8>>,
    BodyLen = bit_size(Body),
    BodyProp = <<0:2, 0:1, CryptoType:3, BodyLen:10>>,
    Header = <<128, 1, BodyProp:16, TelNum:48, RespFlowNum:16>>,
    HeaderBody = <<Header, Body>>,
    XOR = bxorbytelist(HeaderBody),
    RawData = binary:replace(<<HeaderBody, XOR>>, <<125>>, <<125,1>>, [global]),
    RawDataNew = binary:replace(RawData, <<126>>, <<125,2>>, [global]),
    {<<126, RawDataNew, 126>>, State#vdritem{msgflownum=RespFlowNum+1}}.

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
            case delnumfromnumlist([E || E <- lists:seq(1, Total)], Packages) of
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


