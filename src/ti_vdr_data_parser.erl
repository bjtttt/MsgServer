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
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo("Paring data from VDR IP : ~p~n", [Address]);
        {error, Explain} ->
            ti_common:loginfo("Parsing data from unknown VDR : ~p~n", [Explain])
    end,
    try do_parse_data(Socket, State, Data) of
        ok ->
            ok;
        error ->
            error
    catch
        error:Error ->
            ti_common:loginfo("ERROR : parsing data error : ~p~n", [Error]);
        throw:Throw ->
            ti_common:loginfo("ERROR : parsing data throw : ~p~n", [Throw]);
        exit:Exit ->
            ti_common:loginfo("ERROR : parsing data exit : ~p~n", [Exit])
    end.

do_parse_data(_Socket, State, Data) ->
    NoCharityLength = byte_size(Data)-1,
    <<HeaderBody:NoCharityLength,Charity/binary>>=Data,
    case checkheaderbodyparity(HeaderBody, Charity) of
        ok ->
            RestoredData = restore0x7eand0x7d(State, Data),
            <<_IDField:16,BodyPropField:16,_TelNumberField:48,_FlowNumberField:16,RemainField/binary>>=RestoredData,
            <<_ReservedField:2,PackageField:1,_CryptoTypeField:3,BodyLengthField:10>> = BodyPropField,
            case PackageField of
                <<0>> ->
                    Body = RemainField,
                    ActBodyLength = byte_size(Body),
                    <<BodyLength:10>> = BodyLengthField,
                    if
                        BodyLength == ActBodyLength ->
                            ok;
                        BodyLength =/= ActBodyLength ->
                            error
                    end;
                <<1>> ->
                    <<PackageInfoField:32,Body/binary>> = RemainField,
                    ActBodyLength = byte_size(Body),
                    <<PackageTotal:16,PackageIndex:16>> = PackageInfoField,
                    <<BodyLength:10>> = BodyLengthField,
                    if
                        BodyLength == ActBodyLength ->
                            ok;
                        BodyLength =/= ActBodyLength ->
                            error
                    end
            end;
        error ->
            ti_common:logerror("ERROR : data charity error~n")
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

combinepackagemsg(State, Data) ->
    Msg = State#vdritem.msg,
    case getpackagetotalandindex(Data) of
        error ->
            {error, ""}
    {ok, State, VDRMsg}.

%searchinsertextractmsg(State, Data) ->
%    

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
    
dogetpackagetotalandindex(Data) ->
    <<_IDField:16,_BodyPropField:16,_TelNumberField:48,_FlowNumberField:16,PackageInfoField:32,Body/binary>>=Data,
    <<PackageTotal:16,PackageIndex:16>> = PackageInfoField,
    {ok, PackageTotal, PackageIndex}.
    

%%%
%%%
%%%
checkheaderbodyparity(Data, Parity) ->
    Result = bxorbyte(Data),
    if
        Result == Parity ->
            ok;
        Result =/= Parity ->
            error
    end.

%%%
%%%
%%%
bxorbyte(Data) ->
    ByteLength = byte_size(Data),
    case ByteLength of
        0 ->
            <<0>>;
        1 ->
            <<Data:8>>;
        _ ->
            <<Header:8, BinRemain/binary>> = Data,
            <<Remain:8>> = bxorbyte(BinRemain),
            Result = Header bxor Remain,
            <<Result:8>>
    end.

%%%
%%% Process 0x7e & 0x7d
%%%
restore0x7eand0x7d(State, Data) ->
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
                    {ok, FinalResult};%dorestore0x7eand0x7d(BinBody)};
                _ ->
                    ti_common:logerror("ERROR : wrong data tail (~p) from ~p~n",[BinTail, State#vdritem.addr]),
                    error
            end;
        _ ->
            ti_common:logerror("ERROR: wWrong data header (~p) from ~p~n",[BinHeader, State#vdritem.addr]),
            error
    end.

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



