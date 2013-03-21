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
            ti_common:loginfo("Data is from VDR IP : ~p~n", Address);
        {error, Explain} ->
           ti_common:loginfo("Data is from unknown VDR : ~p~n", Explain)
    end,
    RestoredData = restore0x7eand0x7d(State, Data),
    VDRItem = ets:lookup(vdrtable, Socket),
    Length = length(VDRItem),
    case Length of
        1 ->
            % do concrete parse job here
            {ok, RestoredData};
        _ ->
            ti_common:logerror("vdrtable doesn't contain the vdritem.~n"),
            error
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
                    {ok, dorestore0x7eand0x7d(BinBody)};
                _ ->
                    ti_common:logerror("Wrong data tail (~p) from ~p~n",[BinTail, State#vdritem.addr]),
                    error
            end;
        _ ->
            ti_common:logerror("Wrong data header (~p) from ~p~n",[BinHeader, State#vdritem.addr]),
            error
    end.

%%%
%%%
%%%
dorestore0x7eand0x7d(Data) ->
    BinLength = length(Data),
    case BinLength of
        0 ->
            <<>>;
        1 ->
            Data;
        _ ->
            {BinFirst, BinLast} = split_binary(Data, 1),
            case BinFirst of
                <<125>> ->
                    % 125 is 0x7d
                    BinLastLength = length(BinLast),
                    case BinLastLength of 
                        1 ->
                            case BinLast of
                                <<1>> ->
                                    <<125>>;
                                <<2>> ->
                                    <<126>>;
                                _ ->
                                    Data
                            end;
                        _ ->
                            {BinLastFirst, BinLastLast} = split_binary(BinLast, 1),
                            case BinLastFirst of
                                <<1>> ->
                                    list_to_binary([<<125>>, dorestore0x7eand0x7d(BinLastLast)]);
                                <<2>> ->
                                    list_to_binary([<<126>>, dorestore0x7eand0x7d(BinLastLast)]);
                                _ ->
                                    list_to_binary([list_to_binary([BinFirst, BinLastFirst]), dorestore0x7eand0x7d(BinLastLast)])
                            end
                    end;
                _ ->
                    list_to_binary([BinFirst, dorestore0x7eand0x7d(BinLast)])
            end
    end.


%%%
%%% Compose the data to VDR
%%%
compose_data(Data) ->
    Data.

%%%
%%%
%%%



