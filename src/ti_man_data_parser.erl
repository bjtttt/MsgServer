%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_man_data_parser).

-include("ti_header.hrl").

-export([process_data/1]).

-export([create_gen_resp/4,
         create_term_online/1,
         create_term_offline/1,
         create_term_alarm/8,
         create_term_answer/3,
         create_vehicle_ctrl_answer/4,
         create_shot_resp/4]).

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
                        %"0x0001" ->
                        %    if
                        %        Len == 5 ->
                        %            SNPair = element(2, Content),
                        %            SIDPair = element(3, Content),
                        %            ListPair = element(4, Content),
                        %            StatusPair = element(5, Content),
                        %            {"SN", SN} = SNPair,
                        %            {"SID", SID} = SIDPair,
                        %            {"LIST", List} = ListPair,
                        %            {"STATUS", Status} = StatusPair,
                        %            VIDList = get_list("VID", List),
                        %            {ok, Mid, [SN, SID, VIDList, Status]};
                        %        true ->
                        %            {error, length_error}
                        %    end;
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
                        "0x4001" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    SIDPair = element(3, Content),
                                    StatusPair = element(4, Content),
                                    {"SN", SN} = SNPair,
                                    {"SID", SID} = SIDPair,
                                    {"STATUS", Status} = StatusPair,
                                    {ok, Mid, [SN, SID, Status]};
                                true ->
                                    {error, length_error}
                            end;
                        "0x4002" ->
                            if
                                Len == 2 ->
                                    ListPair = element(2, Content),
                                    {"LIST", List} = ListPair,
                                    VIDList = get_list("VID", List),
                                    {ok, Mid, [VIDList]};
                                true ->
                                    {error, length_error}
                            end;
                        %"0x0003" ->
                        %    if
                        %        Len == 2 ->
                        %            ListPair = element(2, Content),
                        %            {"LIST", List} = ListPair,
                        %            VIDList = get_list("VID", List),
                        %            {ok, Mid, [VIDList]};
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        %"0x0004" ->
                        %    if
                        %        Len == 2 ->
                        %            ListPair = element(2, Content),
                        %            {"LIST", List} = ListPair,
                        %            VIDList = get_list("VID", List),
                        %            {ok, Mid, [VIDList]};
                        %        true ->
                        %            {error, length_error}
                        %    end;
                        %"0x0200" ->
                        %    if
                        %        Len == 4 ->
                        %            ListPair = element(2, Content),
                        %            SNPair = element(3, Content),
                        %            DataPair = element(4, Content),
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
                        "0x8103" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            [{"ST", ST}, {"DT", DT}] = DATA,
                                            {ok, Mid, [SN, VIDList, [ST, DT]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8203" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            [{"ASN", ASN}, {"TYPE", TYPE}] = DATA,
                                            {ok, Mid, [SN, VIDList, [ASN, TYPE]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8602" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 12 ->
                                            [{"FLAG", FLAG}, {"LIST", LIST}, {"ID", ID}, {"PROPERTY", PROPERTY}, {"LT_LAT", LT_LAT}, {"LT_LONG", LT_LONG}, {"RB_LAT", RB_LAT}, {"RB_LONG", RB_LONG}, {"ST", ST}, {"ET", ET}, {"MAX_S", MAX_S}, {"LENGTH", LENGTH}] = DATA,
                                            {ok, Mid, [SN, VIDList, [FLAG, LIST, ID, PROPERTY, LT_LAT, LT_LONG, RB_LAT, RB_LONG, ST, ET, MAX_S, LENGTH]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8603" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    [{"LIST", LIST}] = DATA,
                                    DataList = get_list("ID", LIST),
                                    {ok, Mid, [SN, VIDList, DataList]};
                                true ->
                                    {error, length_error}
                            end;
                        "0x8605" ->
                            {error, format_error};
                        "0x8202" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            [{"ITERVAL", ITERVAL}, {"LENGTH", LENGTH}] = DATA,
                                            {ok, Mid, [SN, VIDList, [ITERVAL, LENGTH]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8300" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            [{"FLAG", FLAG}, {"TEXT", TEXT}] = DATA,
                                            {ok, Mid, [SN, VIDList, [FLAG, TEXT]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8302" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 5 ->
                                            [{"FLAG", FLAG}, {"QUES", QUES}, {"ALIST", ALIST}, {"ID", ID}, {"AN", AN}] = DATA,
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
                        %            SNPair = element(2, Content),
                        %            ListPair = element(3, Content),
                        %            DataPair = element(4, Content),
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
                        "0x8400" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            [{"FLAG", FLAG}, {"PHONE", PHONE}] = DATA,
                                            {ok, Mid, [SN, VIDList, [FLAG, PHONE]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8401" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            [{"TYPE", TYPE}, {"LIST", LIST}] = DATA,
                                            PhoneNameList = get_phone_name_list(LIST),
                                            {ok, Mid, [SN, VIDList, [TYPE, PhoneNameList]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x8500" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 1 ->
                                            [{"FLAG", FLAG}] = DATA,
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
                        %            SNPair = element(2, Content),
                        %            StatusPair = element(3, Content),
                        %            ListPair = element(4, Content),
                        %            DataPair = element(5, Content),
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
                        "0x8801" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 10 ->
                                            [{"ID", ID}, {"CMD", CMD}, {"T", T}, {"SF", SF}, {"R", R}, {"Q", Q}, {"B", B}, {"CO", CO}, {"S", S}, {"CH", CH}] = DATA,
                                            {ok, Mid, [SN, VIDList, [ID, CMD, T, SF, R, Q, B, CO, S, CH]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        "0x0805" ->
                            if
                                Len == 5->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    StatusPair = element(4, Content),
                                    DataPair = element(5, Content),
                                    {"SN", SN} = SNPair,
                                    {"LIST", List} = ListPair,
                                    {"STATUS", Status} = StatusPair,
                                    {"DATA", DATA} = DataPair,
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
                        "0x8804" ->
                            if
                                Len == 4 ->
                                    SNPair = element(2, Content),
                                    ListPair = element(3, Content),
                                    DataPair = element(4, Content),
                                    {"LIST", List} = ListPair,
                                    {"SN", SN} = SNPair,
                                    {"DATA", DATA} = DataPair,
                                    VIDList = get_list("VID", List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 4 ->
                                            [{"CMD", CMD}, {"SF", S}, {"T", T}, {"FREQ", FREQ}] = DATA,
                                            {ok, Mid, [SN, VIDList, [CMD, S, T, FREQ]]};
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
%%% MID : 0x0001
%%% List : [ID0, ID1, ID2, ...]
%%%
create_gen_resp(SN, Sid, List, Status) ->
    Bool = is_string(Sid),
    if
        is_integer(SN) andalso Bool andalso is_integer(Status) andalso Status >= 0 andalso Status =< 3 ->
            MIDStr = "\"MID\":\"0x0001\"",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            SidStr = string:concat("\"SID\":", Sid),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
            {ok, combine_strings([MIDStr, SNStr, SidStr, VIDListStr, StatusStr])};
        true ->
            error
    end.

%%%
%%% MID : 0x0003
%%% List : [ID0, ID1, ID2, ...]
%%%
create_term_online(List) ->
    MIDStr = "\"MID\":\"0x0003\"",
    VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
    {ok, combine_strings([MIDStr, VIDListStr])}.

%%%
%%% MID : 0x0004
%%% List : [ID0, ID1, ID2, ...]
%%%
create_term_offline(List) ->
    MIDStr = "\"MID\":\"0x0004\"",
    VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
    {ok, combine_strings([MIDStr, VIDListStr])}.

%%%
%%% MID : 0x0200
%%% List : [ID0, ID1, ID2, ...]
%%%
create_term_alarm(List, SN, Code, AF, SF, Lat, Long, T) ->
    if
        is_integer(SN) ->
            MIDStr = "\"MID\":\"0x0004\"",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            DataListStr = string:concat(string:concat("\"DATA\":{",  create_list(["\"CODE\"", "\"AF\"", "\"SF\"", "\"LAT\"", "\"LONG\"", "\"T\""], [Code, AF, SF, Lat, Long, T], true)), "}"),
            {ok, combine_strings([MIDStr, SNStr, VIDListStr, DataListStr])};
        true ->
            error
    end.

%%%
%%%
%%%
create_term_answer(SN, List, IDList) ->
    if
        is_integer(SN) ->
            MIDStr = "\"MID\":\"0x0302\"",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            DataListStr = string:concat(string:concat("\"DATA\":{",  create_list(["\"ID\""], IDList, true)), "}"),
            {ok, combine_strings([MIDStr, SNStr, VIDListStr, DataListStr])};
        true ->
            error
    end.

%%%
%%%
%%%
create_vehicle_ctrl_answer(SN, Status, List, DataList) ->
    if
        is_integer(SN) andalso is_integer(Status) andalso Status >= 0 andalso Status =< 3 ->
            MIDStr = "\"MID\":\"0x0500\"",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            case Status of
                1 ->
                    DataListStr = string:concat(string:concat("\"DATA\":{",  create_list(["\"FLAG\""], DataList, true)), "}"),
                    {ok, combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr])};
                _ ->
                    DataListStr = "\"DATA\":{}",
                    {ok, combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr])}
            end;
        true ->
            error
    end.

%%%
%%%
%%%
create_shot_resp(SN, List, Status, IDList) ->
    if
        is_integer(SN) andalso is_integer(Status) andalso Status >= 0 andalso Status =< 3 ->
            MIDStr = "\"MID\":\"0x0805\"",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = string:concat(string:concat("\"LIST\":[",  create_list(["\"VID\""], List, false)), "]"),
            StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
            case Status of
                0 ->
                    DataListStr = string:concat(string:concat("\"DATA\":[",  create_list(["\"ID\""], IDList, false)), "]"),
                    {ok, combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr])};
                _ ->
                    DataListStr = "\"DATA\":[]",
                    {ok, combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr])}
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
                                            combine_strings([ID, ":", SVal]);
                                        _ ->
                                            combine_strings(["{", ID, ":", SVal, "}"])
                                        end;
                                _ ->
                                    case IsOne of
                                        true ->
                                            combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]));
                                        _ ->
                                            combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]))
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
                                                    combine_strings([ID, ":", SVal]);
                                                _ ->
                                                    combine_strings(["{", ID, ":", SVal, "}"])
                                                end;
                                        _ ->
                                            case IsOne of
                                                true ->
                                                    combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]));
                                                _ ->
                                                    combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]))
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
                                                            combine_strings([ID, ":", SVal]);
                                                        _ ->
                                                            combine_strings(["{", ID, ":", SVal, "}"])
                                                        end;
                                                _ ->
                                                    case IsOne of
                                                        true ->
                                                            combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]));
                                                        _ ->
                                                            combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]))
                                                    end
                                            end;
                                        _ ->
                                            case is_string(Val) of
                                                true ->
                                                    case T of
                                                        [] ->
                                                            case IsOne of
                                                                true ->
                                                                    combine_strings([ID, ":", Val]);
                                                                _ ->
                                                                    combine_strings(["{", ID, ":", Val, "}"])
                                                                end;
                                                        _ ->
                                                            case IsOne of
                                                                true ->
                                                                    combine_strings(lists:append([ID, ":", Val, ","], [create_list(IDList, T, IsOne)]));
                                                                _ ->
                                                                    combine_strings(lists:append(["{", ID, ":", Val, "},"], [create_list(IDList, T, IsOne)]))
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
                                            combine_strings([ID, ":", SVal]);
                                        _ ->
                                            combine_strings(["{", ID, ":", SVal, "}"])
                                        end;
                                _ ->
                                    case IsOne of
                                        true ->
                                            combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]));
                                        _ ->
                                            combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]))
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
                                                    combine_strings([ID, ":", SVal]);
                                                _ ->
                                                    combine_strings(["{", ID, ":", SVal, "}"])
                                                end;
                                        _ ->
                                            case IsOne of
                                                true ->
                                                    combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]));
                                                _ ->
                                                    combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]))
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
                                                            combine_strings([ID, ":", SVal]);
                                                        _ ->
                                                            combine_strings(["{", ID, ":", SVal, "}"])
                                                        end;
                                                _ ->
                                                    case IsOne of
                                                        true ->
                                                            combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]));
                                                        _ ->
                                                            combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]))
                                                    end
                                            end;
                                        _ ->
                                            case is_string(Val) of
                                                true ->
                                                    case ValTail of
                                                        [] ->
                                                            case IsOne of
                                                                true ->
                                                                    combine_strings([ID, ":", Val]);
                                                                _ ->
                                                                    combine_strings(["{", ID, ":", Val, "}"])
                                                                end;
                                                        _ ->
                                                            case IsOne of
                                                                true ->
                                                                    combine_strings(lists:append([ID, ":", Val, ","], [create_list(IDTail, ValTail, IsOne)]));
                                                                _ ->
                                                                    combine_strings(lists:append(["{", ID, ":", Val, "},"], [create_list(IDTail, ValTail, IsOne)]))
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

%%%
%%%
%%%
is_string(Value) ->
    case is_list(Value) of
        true ->
            Fun = fun(X) ->
                          if X < 0 -> false; 
                             X > 255 -> false;
                             true -> true
                          end
                  end,
            lists:all(Fun, Value);
        _ ->
            false
    end.

%%%
%%% List must be string list
%%%
combine_strings(List) ->
    case List of
        [] ->
            "";
        _ ->
            Fun = fun(X) ->
                          case is_string(X) of
                              true ->
                                  true;
                              _ ->
                                  false
                          end
                  end,
            Bool = lists:all(Fun, List),
            case Bool of
                true ->
                    [H|T] = List,
                    case T of
                        [] ->
                            H;
                        _ ->
                            string:concat(string:concat(H, ","), combine_strings(T))
                    end;
                _ ->
                    ""
            end
    end.
            



