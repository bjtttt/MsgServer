%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(wsock_data_parser).

-include("ti_header.hrl").

-export([process_wsock_message/2]).%,
         %tows_msg_handler/0]).

-export([process_data/1]).

-export([create_gen_resp/4,
         create_init_msg/0,
         create_term_online/1,
         create_term_offline/1,
         create_term_alarm/8,
         create_term_answer/3,
         create_vehicle_ctrl_answer/4,
         create_shot_resp/4]).

%%%
%%%
%%%
%tows_msg_handler() ->
%    receive
%        {wait, Pid , Msg} ->
%            wsock_client:send(Msg),
%            Pid ! {self(), over},
%            tows_msg_handler();
%        {_Pid, Msg} ->
%            wsock_client:send(Msg),
%            tows_msg_handler();
%        stop ->
%            ok;
%        _Other ->
%            tows_msg_handler()
%    end.

%%%
%%%
%%%
process_wsock_message(Type, Msg) ->
    case Type of
        binary ->
            {error, binaryerror};
        text ->
            do_process_data(Msg);
        _ ->
            {error, typeerror}
    end.

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
                    MidPair = lists:nth(1, Content),
                    {"MID", Mid} = MidPair,
                    case Mid of
                        %"0x0001" ->
                        %    if
                        %        Len == 5 ->
                        %            SNPair = lists:nth(2, Content),
                        %            SIDPair = lists:nth(3, Content),
                        %            ListPair = lists:nth(4, Content),
                        %            StatusPair = lists:nth(5, Content),
                        %            {"SN", SN} = SNPair,
                        %            {"SID", SID} = SIDPair,
                        %            {"LIST", List} = ListPair,
                        %            {"STATUS", Status} = StatusPair,
                        %            VIDList = get_list("VID", List),
                        %            {ok, Mid, [SN, SID, VIDList, Status]};
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        16#8001 ->
                            if
                                Len == 5 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"SID", SID} = get_specific_entry(Content, "SID"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"STATUS", Status} = get_specific_entry(Content, "STATUS"),
                                    VIDList = get_list("VID", List),
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
                        16#4001 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"SID", SID} = get_specific_entry(Content, "SID"),
                                    {"STATUS", Status} = get_specific_entry(Content, "STATUS"),
                                    {ok, Mid, [SN, SID, Status]};
                                true ->
                                    {error, length_error}
                            end;
                        16#4002 ->
                            if
                                Len == 2 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    VIDList = get_list("VID", List),
                                    {ok, Mid, [VIDList]};
                                true ->
                                    {error, length_error}
                            end;
                        %"0x0003" ->
                        %    if
                        %        Len == 2 ->
                        %            ListPair = lists:nth(2, Content),
                        %            {"LIST", List} = ListPair,
                        %            VIDList = get_list("VID", List),
                        %            {ok, Mid, [VIDList]};
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        %"0x0004" ->
                        %    if
                        %        Len == 2 ->
                        %            ListPair = lists:nth(2, Content),
                        %            {"LIST", List} = ListPair,
                        %            VIDList = get_list("VID", List),
                        %            {ok, Mid, [VIDList]};
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        %"0x0200" ->
                        %    if
                        %        Len == 4 ->
                        %            ListPair = lists:nth(2, Content),
                        %            SNPair = lists:nth(3, Content),
                        %            DataPair = lists:nth(4, Content),
                        %            {"LIST", List} = ListPair,
                        %            {"SN", SN} = SNPair,
                        %            {"DATA", DATA} = DataPair,
                        %            VIDList = get_list("VID", List),
                        %            DataLen = length(DATA),
                        %            if
                        %                DataLen == 6 ->
                        %                    [{"CODE", Code}, {"AF", AF}, {"SF", SF}, {"LAT", LAT}, {"LONG", LONG}, {"T", T}] = DATA,
                        %                    {ok, Mid, [VIDList, SN, [Code, AF, SF, LAT, LONG, T]]};
                        %                true ->
                        %                    {error, format_error}
                        %            end;
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        16#8103 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"ST", ST} = get_specific_entry(DATA, "ST"),
                                            {"DT", DT} = get_specific_entry(DATA, "DT"),
                                            {ok, Mid, [SN, VIDList, [ST, DT]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8203 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"ASN", ASN} = get_specific_entry(DATA, "ASN"),
                                            {"TYPE", TYPE} = get_specific_entry(DATA, "TYPE"),
                                            {ok, Mid, [SN, VIDList, [ASN, TYPE]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8602 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 12 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"LIST", LIST} = get_specific_entry(DATA, "LIST"),
                                            {"ID", ID} = get_specific_entry(DATA, "ID"),
                                            {"PROPERTY", PROPERTY} = get_specific_entry(DATA, "PROPERTY"),
                                            {"LT_LAT", LT_LAT} = get_specific_entry(DATA, "LT_LAT"),
                                            {"LT_LONG", LT_LONG} = get_specific_entry(DATA, "LT_LONG"),
                                            {"RB_LAT", RB_LAT} = get_specific_entry(DATA, "RB_LAT"),
                                            {"RB_LONG", RB_LONG} = get_specific_entry(DATA, "RB_LONG"),
                                            {"ST", ST} = get_specific_entry(DATA, "ST"),
                                            {"ET", ET} = get_specific_entry(DATA, "ET"),
                                            {"MAX_S", MAX_S} = get_specific_entry(DATA, "MAX_S"),
                                            {"LENGTH", LENGTH} = get_specific_entry(DATA, "LENGTH"),
                                            {ok, Mid, [SN, VIDList, [FLAG, LIST, ID, PROPERTY, LT_LAT, LT_LONG, RB_LAT, RB_LONG, ST, ET, MAX_S, LENGTH]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8603 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    [{"LIST", LIST}] = DATA,
                                    DataList = get_list("ID", LIST),
                                    {ok, Mid, [SN, VIDList, DataList]};
                                true ->
                                    {error, length_error}
                            end;
                        16#8605 ->
                            {error, format_error};
                        16#8202 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"ITERVAL", ITERVAL} = get_specific_entry(DATA, "ITERVAL"),
                                            {"LENGTH", LENGTH} = get_specific_entry(DATA, "LENGTH"),
                                            {ok, Mid, [SN, VIDList, [ITERVAL, LENGTH]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8300 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"TEXT", TEXT} = get_specific_entry(DATA, "TEXT"),
                                            {ok, Mid, [SN, VIDList, [FLAG, TEXT]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8302 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 5 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"QUES", QUES} = get_specific_entry(DATA, "QUES"),
                                            {"ALIST", ALIST} = get_specific_entry(DATA, "ALIST"),
                                            {"ID", ID} = get_specific_entry(DATA, "ID"),
                                            {"AN", AN} = get_specific_entry(DATA, "AN"),
                                            {ok, Mid, [SN, VIDList, [FLAG, QUES, ALIST, ID, AN]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        %"0x0302" ->
                        %    if
                        %        Len == 4 ->
                        %            SNPair = lists:nth(2, Content),
                        %            ListPair = lists:nth(3, Content),
                        %            DataPair = lists:nth(4, Content),
                        %            {"LIST", List} = ListPair,
                        %            {"SN", SN} = SNPair,
                        %            {"DATA", DATA} = DataPair,
                        %            VIDList = get_list("VID", List),
                        %            DataLen = length(DATA),
                        %            if
                        %                DataLen == 1 ->
                        %                    [{"ID", ID}] = DATA,
                        %                    {ok, Mid, [SN, VIDList, [ID]]};
                        %                true ->
                        %                    {error, format_error}
                        %            end;
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        16#8400 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"PHONE", PHONE} = get_specific_entry(DATA, "PHONE"),
                                            {ok, Mid, [SN, VIDList, [FLAG, PHONE]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8401 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"TYPE", TYPE} = get_specific_entry(DATA, "TYPE"),
                                            {"LIST", LIST} = get_specific_entry(DATA, "LIST"),
                                            PhoneNameList = get_phone_name_list(LIST),
                                            {ok, Mid, [SN, VIDList, [TYPE, PhoneNameList]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8500 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 1 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {ok, Mid, [SN, VIDList, FLAG]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        %"0x0500" ->
                        %    if
                        %        Len == 5 ->
                        %            SNPair = lists:nth(2, Content),
                        %            StatusPair = lists:nth(3, Content),
                        %            ListPair = lists:nth(4, Content),
                        %            DataPair = lists:nth(5, Content),
                        %            {"SN", SN} = SNPair,
                        %            {"STATUS", Status} = StatusPair,
                        %            {"LIST", List} = ListPair,
                        %            {"DATA", DATA} = DataPair,
                        %            VIDList = get_list("VID", List),
                        %            DataLen = length(DATA),
                        %            case Status of
                        %                0 ->
                        %                    if
                        %                        DataLen =/= 0 ->
                        %                            {error, format_error};
                        %                        true ->
                        %                            {ok, Mid, [SN, Status, VIDList, []]}
                        %                    end;
                        %                _ ->
                        %                    if
                        %                        DataLen == 0 ->
                        %                            {error, format_error};
                        %                        true ->
                        %                            if
                        %                                DataLen == 1 ->
                        %                                    [{"FLAG", FLAG}] = DATA,
                        %                                    {ok, Mid, [SN, Status, VIDList, FLAG]};
                        %                                true ->
                        %                                    {error, format_error}
                        %                            end
                        %                    end
                        %            end;
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        16#8801 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 10 ->
                                            {"ID", ID} = get_specific_entry(DATA, "ID"),
                                            {"CMD", CMD} = get_specific_entry(DATA, "CMD"),
                                            {"T", T} = get_specific_entry(DATA, "T"),
                                            {"SF", SF} = get_specific_entry(DATA, "SF"),
                                            {"R", R} = get_specific_entry(DATA, "R"),
                                            {"Q", Q} = get_specific_entry(DATA, "Q"),
                                            {"B", B} = get_specific_entry(DATA, "B"),
                                            {"CO", CO} = get_specific_entry(DATA, "CO"),
                                            {"S", S} = get_specific_entry(DATA, "S"),
                                            {"CH", CH} = get_specific_entry(DATA, "CH"),
                                            {ok, Mid, [SN, VIDList, [ID, CMD, T, SF, R, Q, B, CO, S, CH]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#805 ->
                            if
                                Len == 5->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"STATUS", Status} = get_specific_entry(Content, "STATUS"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    case Status of
                                        0 ->
                                            if
                                                DataLen =/= 0 ->
                                                    {error, format_error};
                                                true ->
                                                    {ok, Mid, [SN, Status, VIDList, []]}
                                            end;
                                        _ ->
                                            if
                                                DataLen == 0 ->
                                                    {error, format_error};
                                                true ->
                                                    if
                                                        DataLen > 0 ->
                                                            DataList = get_list("ID", DATA),
                                                            {ok, Mid, [SN, VIDList, Status, DataList]};
                                                        true ->
                                                            {error, format_error}
                                                    end
                                            end
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8804 ->
                            if
                                Len == 4 ->
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"DATA", DATA} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 4 ->
                                            {"CMD", CMD} = get_specific_entry(DATA, "CMD"),
                                            {"TIME", TIME} = get_specific_entry(DATA, "TIME"),
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"FREQ", FREQ} = get_specific_entry(DATA, "FREQ"),
                                            {ok, Mid, [SN, VIDList, [CMD, TIME, FLAG, FREQ]]};
                                        true ->
                                            {error, format_error}
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
get_specific_entry(List, ID) ->
    case List of
        [] ->
            {ID, null};
        _ ->
            [H|T] = List,
            case is_tuple(H) of
                true ->
                    case tuple_size(H) of
                        2 ->
                            HID = element(1, H),
                            HValue = element(2, H),
                            if
                                HID == ID ->
                                    {ID, HValue};
                                true ->
                                    case T of
                                        [] ->
                                            {ID, null};
                                        _ ->
                                            get_specific_entry(T, ID)
                                    end
                            end
                    end;
                _ ->
                    case T of
                        [] ->
                            {ID, null};
                        _ ->
                            get_specific_entry(T, ID)
                    end
            end
    end.
                    

%%%
%%%
%%%
get_list(ID, VIDList) ->
    Len = length(VIDList),
    if
        Len < 1 ->
            [];
        true ->
            [H|T] = VIDList,
            {ID, VID} = H,
            [VID|get_list(ID, T)]
    end.

%%%
%%%
%%%
get_phone_name_list(PhoneNameList) ->
    Len = length(PhoneNameList),
    if
        Len < 1 ->
            [];
        true ->
            [H|T] = PhoneNameList,
            Len = length(H),
            if
                Len == 3 ->
                    [{"FLAG", FLAG}, {"PHONE", PHONE}, {"NAME", NAME}] = H,
                    [[FLAG, PHONE, NAME]|get_phone_name_list(T)];
                true ->
                    get_phone_name_list(T)
            end
    end.
    
%%%
%%%
%%%
create_init_msg() ->
    {ok, "{\"MID\":5, \"TOKEN\":\"anystring\"}"}.

%%%
%%% MID : 0x0001
%%% List : [ID0, ID1, ID2, ...]
%%%
create_gen_resp(SN, Sid, List, Status) ->
    Bool = ti_common:is_string(Sid),
    if
        is_integer(SN) andalso Bool andalso is_integer(Status) andalso Status >= 0 andalso Status =< 3 ->
            MIDStr = "\"MID\":1",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            SidStr = string:concat("\"SID\":", Sid),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
            {ok, ti_common:combine_strings(["{", MIDStr, SNStr, SidStr, VIDListStr, StatusStr, "}"])};
        true ->
            error
    end.

%%%
%%% MID : 0x0003
%%% List : [ID0, ID1, ID2, ...]
%%%
create_term_online(List) ->
    MIDStr = "\"MID\":3",
    VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
    {ok, ti_common:combine_strings(["{", MIDStr, VIDListStr, "}"])}.

%%%
%%% MID : 0x0004
%%% List : [ID0, ID1, ID2, ...]
%%%
create_term_offline(List) ->
    MIDStr = "\"MID\":4",
    VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
    {ok, ti_common:combine_strings(["{", MIDStr, VIDListStr, "}"])}.

%%%
%%% MID : 0x0200
%%% List : [ID0, ID1, ID2, ...]
%%%
create_term_alarm(List, SN, Code, AF, SF, Lat, Long, T) ->
    if
        is_integer(SN) ->
            MIDStr = "\"MID\":512",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            DataListStr = string:concat(string:concat("\"DATA\":{",  create_list(["\"CODE\"", "\"AF\"", "\"SF\"", "\"LAT\"", "\"LONG\"", "\"T\""], [Code, AF, SF, Lat, Long, T], true)), "}"),
            {ok, ti_common:combine_strings(["{", MIDStr, SNStr, VIDListStr, DataListStr, "}"])};
        true ->
            error
    end.

%%%
%%% 0x0302
%%%
create_term_answer(SN, List, IDList) ->
    if
        is_integer(SN) ->
            MIDStr = "\"MID\":770",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            DataListStr = string:concat(string:concat("\"DATA\":{",  create_list(["\"ID\""], IDList, true)), "}"),
            {ok, ti_common:combine_strings(["{", MIDStr, SNStr, VIDListStr, DataListStr, "}"])};
        true ->
            error
    end.

%%%
%%% 0x0500
%%%
create_vehicle_ctrl_answer(SN, Status, List, DataList) ->
    if
        is_integer(SN) andalso is_integer(Status) andalso Status >= 0 andalso Status =< 3 ->
            MIDStr = "\"MID\":1280",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            case Status of
                1 ->
                    DataListStr = string:concat(string:concat("\"DATA\":{",  create_list(["\"FLAG\""], DataList, true)), "}"),
                    {ok, ti_common:combine_strings(["{", MIDStr, SNStr, StatusStr, VIDListStr, DataListStr, "}"])};
                _ ->
                    DataListStr = "\"DATA\":{}",
                    {ok, ti_common:combine_strings(["{", MIDStr, SNStr, StatusStr, VIDListStr, DataListStr, "}"])}
            end;
        true ->
            error
    end.

%%%
%%% 0x0805
%%%
create_shot_resp(SN, List, Status, IDList) ->
    if
        is_integer(SN) andalso is_integer(Status) andalso Status >= 0 andalso Status =< 3 ->
            MIDStr = "\"MID\":2053",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
            case Status of
                0 ->
                    DataListStr = string:concat(string:concat("\"DATA\":[",  create_list(["\"ID\""], IDList, false)), "]"),
                    {ok, ti_common:combine_strings(["{", MIDStr, SNStr, StatusStr, VIDListStr, DataListStr, "}"])};
                _ ->
                    DataListStr = "\"DATA\":[]",
                    {ok, ti_common:combine_strings(["{", MIDStr, SNStr, StatusStr, VIDListStr, DataListStr, "}"])}
            end;
        true ->
            error
    end.

%%%
%%% When IsOne == true, the result is like : "A":XA,"B":XB,"C":XC,...
%%% When IsOne == false, the result is like : {"A":XA},{"B":XB},{"C":XC},...
%%%
create_list(IDList, List, IsOne) ->
    IDListLen = length(IDList),
    ListLen = length(List),
    if
        IDListLen < 1 ->
            "";
        IDListLen == 1 ->
            [ID|_] = IDList,
            if
                ListLen < 1 ->
                    "";
                true ->
                    [Val|T] = List,
                    case is_integer(Val) of
                        true ->
                            SVal = integer_to_list(Val),
                            case T of
                                [] ->
                                    case IsOne of
                                        true ->
                                            ti_common:combine_strings([ID, ":", SVal], false);
                                        _ ->
                                            ti_common:combine_strings(["{", ID, ":", SVal, "}"], false)
                                        end;
                                _ ->
                                    case IsOne of
                                        true ->
                                            ti_common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]), false);
                                        _ ->
                                            ti_common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]), false)
                                    end
                            end;
                        _ ->
                            case is_float(Val) of
                                true ->
                                    SVal = float_to_list(Val),
                                    case T of
                                        [] ->
                                            case IsOne of
                                                true ->
                                                    ti_common:combine_strings([ID, ":", SVal], false);
                                                _ ->
                                                    ti_common:combine_strings(["{", ID, ":", SVal, "}"], false)
                                                end;
                                        _ ->
                                            case IsOne of
                                                true ->
                                                    ti_common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]), false);
                                                _ ->
                                                    ti_common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]), false)
                                            end
                                    end;
                                _ ->
                                    case is_atom(Val) of
                                        true ->
                                            SVal = atom_to_list(Val),
                                            case T of
                                                [] ->
                                                    case IsOne of
                                                        true ->
                                                            ti_common:combine_strings([ID, ":", SVal], false);
                                                        _ ->
                                                            ti_common:combine_strings(["{", ID, ":", SVal, "}"], false)
                                                        end;
                                                _ ->
                                                    case IsOne of
                                                        true ->
                                                            ti_common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]), false);
                                                        _ ->
                                                            ti_common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]), false)
                                                    end
                                            end;
                                        _ ->
                                            case ti_common:is_string(Val) of
                                                true ->
                                                    case T of
                                                        [] ->
                                                            case IsOne of
                                                                true ->
                                                                    ti_common:combine_strings([ID, ":", Val], false);
                                                                _ ->
                                                                    ti_common:combine_strings(["{", ID, ":", Val, "}"], false)
                                                                end;
                                                        _ ->
                                                            case IsOne of
                                                                true ->
                                                                    ti_common:combine_strings(lists:append([ID, ":", Val, ","], [create_list(IDList, T, IsOne)]), false);
                                                                _ ->
                                                                    ti_common:combine_strings(lists:append(["{", ID, ":", Val, "},"], [create_list(IDList, T, IsOne)]), false)
                                                            end
                                                    end;
                                                _ ->
                                                    case T of
                                                        [] ->
                                                            [];
                                                        _ ->
                                                            create_list(IDList, T, IsOne)
                                                    end
                                            end
                                    end
                            end
                    end
            end;
        IDListLen > 1 ->
            if
                IDListLen =/= ListLen ->
                    "";
                true ->
                    [ID|IDTail] = IDList,
                    [Val|ValTail] = List,
                    case is_integer(Val) of
                        true ->
                            SVal = integer_to_list(Val),
                            case ValTail of
                                [] ->
                                    case IsOne of
                                        true ->
                                            ti_common:combine_strings([ID, ":", SVal]);
                                        _ ->
                                            ti_common:combine_strings(["{", ID, ":", SVal, "}"])
                                        end;
                                _ ->
                                    case IsOne of
                                        true ->
                                            ti_common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]));
                                        _ ->
                                            ti_common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]))
                                    end
                            end;
                        _ ->
                            case is_float(Val) of
                                true ->
                                    SVal = float_to_list(Val),
                                    case ValTail of
                                        [] ->
                                            case IsOne of
                                                true ->
                                                    ti_common:combine_strings([ID, ":", SVal]);
                                                _ ->
                                                    ti_common:combine_strings(["{", ID, ":", SVal, "}"])
                                                end;
                                        _ ->
                                            case IsOne of
                                                true ->
                                                    ti_common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]));
                                                _ ->
                                                    ti_common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]))
                                            end
                                    end;
                                _ ->
                                    case is_atom(Val) of
                                        true ->
                                            SVal = atom_to_list(Val),
                                            case ValTail of
                                                [] ->
                                                    case IsOne of
                                                        true ->
                                                            ti_common:combine_strings([ID, ":", SVal]);
                                                        _ ->
                                                            ti_common:combine_strings(["{", ID, ":", SVal, "}"])
                                                        end;
                                                _ ->
                                                    case IsOne of
                                                        true ->
                                                            ti_common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]));
                                                        _ ->
                                                            ti_common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]))
                                                    end
                                            end;
                                        _ ->
                                            case ti_common:is_string(Val) of
                                                true ->
                                                    case ValTail of
                                                        [] ->
                                                            case IsOne of
                                                                true ->
                                                                    ti_common:combine_strings([ID, ":", Val]);
                                                                _ ->
                                                                    ti_common:combine_strings(["{", ID, ":", Val, "}"])
                                                                end;
                                                        _ ->
                                                            case IsOne of
                                                                true ->
                                                                    ti_common:combine_strings(lists:append([ID, ":", Val, ","], [create_list(IDTail, ValTail, IsOne)]));
                                                                _ ->
                                                                    ti_common:combine_strings(lists:append(["{", ID, ":", Val, "},"], [create_list(IDTail, ValTail, IsOne)]))
                                                            end
                                                    end;
                                                _ ->
                                                    case ValTail of
                                                        [] ->
                                                            [];
                                                        _ ->
                                                            create_list(IDTail, ValTail, IsOne)
                                                    end
                                            end
                                    end
                            end
                    end
            end
    end.

            



