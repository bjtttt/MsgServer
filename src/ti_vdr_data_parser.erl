%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_data_parser).

-include("ti_header.hrl").

-export([restore_data/1, parse_data/3, compose_data/1]).

%%%
%%% check 0x7d
%%%
restore_data(Data) ->
    Data.

%%%
%%% Parse the data from VDR
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
        ok ->
            ok;
        Error ->
            Error
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
%%% Return :
%%%     ok
%%%     {error, }
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
                            ok;
                        BodyLen =/= ActBodyLen ->
                            % Ask VDR resend this msg
                            {error, [FlowNumberField]}
                    end;
                1 ->
                    <<PackageInfoField:32,Body/binary>> = TailField,
                    ActBodyLen = byte_size(Body),
                    <<Total:16,Index:16>> = PackageInfoField,
                    if
                        Total =< 1 ->
                            {error, [FlowNumberField]};
                        Total > 1 ->
                            if
                                Index > Total ->
                                    {error, [FlowNumberField]};
                                Index =< Total ->
                                    <<BodyLen:10>> = BodyLenField,
                                    if
                                        BodyLen == ActBodyLen ->
                                            combinemsgpacks(State, IDField, FlowNumberField, Total, Index, Body),
                                            ok;
                                        BodyLen =/= ActBodyLen ->
                                            % Ask VDR resend this msg
                                            {error, [FlowNumberField]}
                                    end
                            end
                    end
            end;
        CalcParity =/= Parity ->
            ti_common:logerror("ERROR : calculated parity (~p) =/= data parity (~p)~n", [CalcParity, Parity])
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
%%%
combinemsgpacks(State, ID, FlowIndex, Total, Index, Body) ->
    CurAllMsg = State#vdritem.msg,
    % Get all msg packages with the same ID
    CurAllMsgWithID = extractallmsgbyid(CurAllMsg, ID),
    % Get all msg packages without the same ID
    CurAllMsgWithoutID = extractallmsgbynotid(CurAllMsg, ID),
    case CurAllMsgWithID of
        [] ->
            
    case getpackagetotalandindex(Data) of
        {ok, PackageTotal, PackageIndex} ->
            NewAllMsgByID = [[ID, FlowIndex, Data]|removemsgpackagebyindex(CurAllMsgByID, ID, PackageIndex)],
            case getnotexistindexlist(NewAllMsgByID, ID, PackageTotal) of
                [] ->
                    % Remove the related requests from State#vdritem.req & the related msg packages from State#vdritem.msg
                    NewState = State#vdritem{msg=CurAllMsgByNotID, req=delmsgpackreqbyid(State#vdritem.req, ID)},
                    % Compose the msg here
                    % Call ASN.1 parser here
                    {ok, NewState};
                _ ->
                    ok
            end;
        error ->
            {error, ""}
    end.


%%%
%%%
%%%
delmsgpackreqbyid(Reqs, ID) ->
    case Reqs of
        [] ->
            [];
        _ ->
            [H|T] = Reqs,
            [HID,_HIdx] = H,
            if
                HID == ID ->
                    delmsgpackreqbyid(T, ID);
                HID =/= ID ->
                    [H|delmsgpackreqbyid(T, ID)]
            end
    end.

%%%
%%% Get the unreceived package indexes for vdritem.req
%%%
getnotexistindexlist(Msg, ID, PackageTotal) ->
    AllNumberList = numberlist(PackageTotal),
    ExistNumberList = getexistnumberlist(Msg, []),
    NotExistNumberList = removenumberfromlist(AllNumberList, ExistNumberList),
    composemsgpackagereq(ID, NotExistNumberList).


%%%
%%%
%%%
composemsgpackagereq(ID, NumberList) ->
    case NumberList of
        [] ->
            [];
        _ ->
            [Header|Tail] = NumberList,
            [[ID, Header]|composemsgpackagereq(ID, Tail)]
    end.

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
getexistnumberlist(Msg, NumberList) ->
    case Msg of
        [] ->
            NumberList;
        _ ->
            [[ID,FlowIndex,Data]|Tail] = Msg,
            case getpackagetotalandindex(Data) of
                error ->
                    getexistnumberlist(Tail, NumberList);
                {ok, _PackageTotal, PackageIndex} ->
                    [[ID,FlowIndex,PackageIndex]|getexistnumberlist(Tail, NumberList)]
            end
    end.

%%%
%%% Internal usage
%%% Remove the specific number from the number list
%%% Return
%%%     if packagetotal == 6 and [[ID0,FlowIndex0,1],[ID1,FlowIndex1,3],[ID2,FlowIndex2,4]]
%%%     [6,5,2]
%%%
removenumberfromlist(NumberList, RemoveNumberList) ->
    case RemoveNumberList of
        [] ->
            NumberList;
        _ ->
            [Header|Tail] = RemoveNumberList,
            [_ID,_FlowIndex,PackageIndex] = Header,
            removenumberfromlist([E || E <- NumberList, E =/= PackageIndex], Tail)
    end.


%%%
%%% Remove msg package with the same ID and Index from the msg packages
%%%
removemsgpackagebyindex(Msg, ID, Index) ->
    case Msg of
        [] ->
            [];
        _ ->
            [Header|Tail] = Msg,
            [HeaderID,_HeaderFlowIndex,_HeaderBody] = Header,
            if
                HeaderID == ID ->
                    case getpackagetotalandindex(Header) of
                        error ->
                            [Header,removemsgpackagebyindex(Tail,ID,Index)];
                        {ok,_PackageTotal,PackageIndex} ->
                            if
                                PackageIndex == Index ->
                                    removemsgpackagebyindex(Tail,ID,Index);
                                PackageIndex =/= Index ->
                                    [Header,removemsgpackagebyindex(Tail,ID,Index)]
                            end
                    end;
                HeaderID =/= ID ->
                    [Header,removemsgpackagebyindex(Tail,ID,Index)]
            end
    end.

%%%
%%% For example,
%%%     NumberList = [6,5,4,3,2,1]
%%%     Msg : [[ID0,FlowIndex0,Data0],[ID1,FlowIndex1,Data1],[ID2,FlowIndex2,Data2],[ID3,FlowIndex3,Data3],...
%%% Get packagetotal and packageindex from Datan,
%%% Remove packageindex from NumberList.
%%% This function is to get the NOT existed msg package indexes.
%%%
removeexistnumberfromlist(NumberList, Msg) ->
    case Msg of
        [] ->
            NumberList;
        _ ->
            [[_ID,_FlowIndex,Data]|Tail] = Msg,
            case getpackagetotalandindex(Data) of
                error ->
                    removeexistnumberfromlist(NumberList, Tail);
                {ok, _PackageTotal, PackageIndex} ->
                    NewNumberList = [E || E <- NumberList, E =/= PackageIndex],
                    removeexistnumberfromlist(NewNumberList, Tail)
            end
    end.

%%%
%%% Msg : [[ID0,Data0],[ID1,Data1],[ID2,Data2],[ID3,Data3],...
%%% This function is to created a new list with the ones whose IDn is the same as ID.
%%%
extractallmsgbyid(Msg, ID) ->
    case Msg of
        [] ->
            Msg;
        _ ->
            [Header|Tail] = Msg,
            [HeaderID,_HeaderFlowIndex,_HeaderData] = Header,
            if
                HeaderID == ID ->
                    [Header|extractallmsgbyid(Tail, ID)];
                HeaderID =/= ID ->
                    extractallmsgbyid(Tail, ID)
            end
    end.

%%%
%%% Msg : [[ID0,Data0],[ID1,Data1],[ID2,Data2],[ID3,Data3],...
%%% This function is to created a new list with the ones whose IDn is NOT the same as ID.
%%%
extractallmsgbynotid(Msg, ID) ->
    case Msg of
        [] ->
            Msg;
        _ ->
            [Header|Tail] = Msg,
            [HeaderID,_HeaderFlowIndex,_HeaderData] = Header,
            if
                HeaderID == ID ->
                    extractallmsgbyid(Tail, ID);
                HeaderID =/= ID ->
                    [Header|extractallmsgbyid(Tail, ID)]
            end
    end.

%%%
%%% Return :
%%%     {ok, PackageTotal, PackageIndex}
%%%     error
%%%
getpackagetotalandindex(Data) ->
    try dogetpackagetotalandindex(Data) of
        {ok, PackageTotal, PackageIndex} ->
            {ok, PackageTotal, PackageIndex}
    catch
        error:Error ->
            ti_common:loginfo("ERROR : get data package total & index error : ~p~n", [Error]),
            error;
        throw:Throw ->
            ti_common:loginfo("ERROR : get data package total & index throw : ~p~n", [Throw]),
            error;
        exit:Exit ->
            ti_common:loginfo("ERROR : get data package total & index exit : ~p~n", [Exit]),
            error
    end.

%%%
%%% internal usage
%%% {ok, PackageTotal, PackageIndex}
%%%
dogetpackagetotalandindex(Data) ->
    <<_IDField:16,_BodyPropField:16,_TelNumberField:48,_FlowNumberField:16,PackageInfoField:32,_Body/binary>>=Data,
    <<PackageTotal:16,PackageIndex:16>> = PackageInfoField,
    {ok, PackageTotal, PackageIndex}.


%%%
%%% Check whether it is a sub-package
%%%
checksubpackage(State, Data) ->
    ok.

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


%%%
%%% Compose the data to VDR
%%%
compose_data(Data) ->
    Data.

%%%
%%%
%%%



