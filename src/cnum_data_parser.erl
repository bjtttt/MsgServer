%%%
%%% This file is use to parse the data from monitor
%%%

-module(cnum_data_parser).

-export([parse_data/2]).

-include("header.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_data(Data, State) ->
    NewData = get_data_binary(Data),
    try do_process_data(NewData, State)
    catch
        _:Why ->
            [ST] = erlang:get_stacktrace(),
            common:logerr("Parsing CNUM data exception : ~p~n~p~nStack trace :~n~p", [Why, Data, ST])
    end.

do_process_data(Data, State) ->
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
                                    common:loginfo("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p", [MsgIdx, State#vdritem.addr, BodyLen, ActBodyLen]),
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
                                    common:loginfo("Total error for msg (~p) from (~p) : ~p", [MsgIdx, State#vdritem.addr, Total]),
                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                Total > 1 ->
                                    if
                                        Index < 1 ->
                                            common:send_stat_err(State, packerr),
                                            common:loginfo("Index error for msg (~p) from (~p) : (Index)~p", [MsgIdx, State#vdritem.addr, Index]),
                                            {warning, HeadInfo, ?P_GENRESP_ERRMSG, State};
                                        Index > Total ->
                                            common:send_stat_err(State, packerr),
                                            common:loginfo("Index error for msg (~p) from (~p) : (Total)~p:(Index)~p", [MsgIdx, State#vdritem.addr, Total, Index]),
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
                                                    common:loginfo("Length error for msg (~p) from (~p) : (Field)~p:(Actual)~p", [MsgIdx, State#vdritem.addr, BodyLen, ActBodyLen]),
                                                    {warning, HeadInfo, ?P_GENRESP_ERRMSG, State}
                                            end
                                    end
                            end
                    end;
                CalcParity =/= Parity ->
                    common:send_stat_err(State, parerr),
                    common:loginfo("Parity error (calculated)~p:(data)~p from ~p", [CalcParity, Parity, State#vdritem.addr]),
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

get_data_binary(Data) ->
    IsList = is_list(Data),
    if
        IsList == true ->
            [BinData] = Data,
            BinData;
        true ->
            Data
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
            common:loginfo("Wrong data head/tail from ~p~n: (Head)~p / (Tail)~p",[State#vdritem.addr, Head, Tail]),
            error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
