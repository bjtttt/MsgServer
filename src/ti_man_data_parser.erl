%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_man_data_parser).

-include("ti_header.hrl").

-export([process_data/1]).

%%%
%%% Maybe State is useless
%%% Data : binary() | [byte()]
%%% Maybe State is useless
%%%
%%% Return :
%%%     {ok, Mid, Res}
%%%     {error, length_error}
%%%     {error, format_error}
%%%     {error, Reason}
%%%     {error, exception, Why}
%%%
process_data(Data) ->
    try do_process_data(Data)
    catch
        _:Why ->
            ti_common:loginfo("Parsing management data exception : ~p~n", [Why]),
            {error, exception, Why}
    end.

%%%
%%% Maybe State is useless
%%%
%%% Return :
%%%     {ok, Mid, Res}
%%%     {error, length_error}
%%%     {error, format_error}
%%%     {error, Reason}
%%%
do_process_data(Data) ->
    case ti_rfc4627:decode(Data) of
        {ok, Erl, _Rest} ->
            {obj, Content} = Erl,
            Len = length(Content),
            if
                Len < 1 ->
                    {error, length_error};
                true ->
                    MidPair = element(1, Content),
                    {"MID", Mid} = MidPair,
                    case Mid of
                        "0x0001" ->
                            if
                                Len == 5 ->
                                    SNPair = element(2, Content),
                                    SIDPair = element(3, Content),
                                    ListPair = element(4, Content),
                                    StatusPair = element(5, Content),
                                    {"SN", SN} = SNPair,
                                    {"SID", SID} = SIDPair,
                                    {"LIST", List} = ListPair,
                                    {"STATUS", Status} = StatusPair,
                                    VIDList = get_vid_list(List),
                                    {ok, Mid, [SN, SID, VIDList, Status]};
                                true ->
                                    {error, length_error}
                            end;
                        "0x8001" ->
                            if
                                Len == 5 ->
                                    SNPair = element(2, Content),
                                    SIDPair = element(3, Content),
                                    ListPair = element(4, Content),
                                    StatusPair = element(5, Content),
                                    {"SN", SN} = SNPair,
                                    {"SID", SID} = SIDPair,
                                    {"LIST", List} = ListPair,
                                    {"STATUS", Status} = StatusPair,
                                    VIDList = get_vid_list(List),
                                    LenVIDList = length(VIDList),
                                    case Status of
                                        0 ->
                                            if
                                                LenVIDList =/= 0 ->
                                                    {error, format_error};
                                                true ->
                                                    {ok, Mid, [SN, SID, Status, VIDList]}
                                            end;
                                        _ ->
                                            if
                                                LenVIDList == 0 ->
                                                    {error, format_error};
                                                true ->
                                                    {ok, Mid, [SN, SID, Status, VIDList]}
                                            end
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        _ ->
                            {error, format_error}
                    end
            end;
        {error, Reason} ->
            {error, Reason}
    end.

%%%
%%%
%%%
get_vid_list(VIDList) ->
    Len = length(VIDList),
    if
        Len < 1 ->
            [];
        true ->
            [H|T] = VIDList,
            {"VID", VID} = H,
            [VID|get_vid_list(T)]
    end.

