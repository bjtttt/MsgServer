%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(wsock_data_parser).

-include("header.hrl").

-export([process_wsock_message/1,
         process_wsock_message/2]).%,
         %tows_msg_handler/0]).

%-export([process_data/1]).

-export([create_gen_resp/4,
         create_pulse/0,
         create_init_msg/0,
         create_term_online/1,
         create_term_offline/1,
         create_authen/1,
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
process_wsock_message(Msg) ->
    process_wsock_message(text, Msg).
process_wsock_message(Type, Msg) ->
    case Type of
        binary ->
            {error, binaryerror};
        text ->
            Ret = process_data(Msg),
            connect_ws_to_vdr(Ret),
            Ret;
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
            common:loginfo("Parsing management data exception : ~p~n", [Why]),
            {error, exception, Why}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Return    :
%     {ok, Mid, Res}
%     {error, length_error}
%     {error, format_error}
%     {error, Reason}
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
do_process_data(Data) ->
    common:loginfo("WS Server MSG : ~p~n", [Data]),
    case rfc4627:decode(Data) of
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
                        16#8001 ->
                            if
                                Len == 5 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"SID", SID} = get_specific_entry(Content, "SID"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"STATUS", Status} = get_specific_entry(Content, "STATUS"),
                                    VIDList = get_same_key_list(List),
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
                                    VIDList = get_same_key_list(List),
                                    {ok, Mid, [VIDList]};
                                true ->
                                    {error, length_error}
                            end;
                        16#4003 ->
                            if
                                Len == 2 ->
                                    {"TOKEN", Token} = get_specific_entry(Content, "TOKEN"),
                                    {ok, Mid, Token};
                                true ->
                                    {error, length_error}
                            end;
                        16#8103 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 orelse DataLen == 1 orelse DataLen == 0 ->
                                            {"ST", STPart} = get_specific_entry(DATA, "ST"),
                                            {"DT", DTPart} = get_specific_entry(DATA, "DT"),
                                            case STPart of
                                                {obj, ST} ->
                                                    case DTPart of
                                                        {obj, DT} ->
                                                            {ok, Mid, [SN, VIDList, [ST, DT]]};
                                                        _ ->
                                                            {ok, Mid, [SN, VIDList, [ST, []]]}
                                                    end;
                                                _ ->
                                                    case DTPart of
                                                        {obj, DT} ->
                                                            {ok, Mid, [SN, VIDList, [[], DT]]};
                                                        _ ->
                                                            {ok, Mid, [SN, VIDList, [[], []]]}
                                                    end
                                            end;
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8203 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 2 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"LIST", LIST} = get_specific_entry(DATA, "LIST"),
                                            RECT = get_rect_area_list(LIST),
                                            {ok, Mid, [SN, VIDList, FLAG, RECT]};
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
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
                                    [{"LIST", LIST}] = DATA,
                                    DataList = get_same_key_list(LIST),
                                    {ok, Mid, [SN, VIDList, DataList]};
                                true ->
                                    {error, length_error}
                            end;
                        16#8105 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 1 ->
                                            {"CMD", CMD} = get_specific_entry(DATA, "CMD"),
                                            {ok, Mid, [SN, VIDList, {CMD}]};
                                        DataLen == 2 ->
                                            {"CMD", CMD} = get_specific_entry(DATA, "CMD"),
                                            {"PARAM", PARAM} = get_specific_entry(DATA, "PARAM"),
                                            {ok, Mid, [SN, VIDList, {CMD, PARAM}]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8202 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 3 ->
                                            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
                                            {"QUES", QUES} = get_specific_entry(DATA, "QUES"),
                                            {"ALIST", ALIST} = get_specific_entry(DATA, "ALIST"),
                                            IDAns = get_answer_list(ALIST),
                                            {ok, Mid, [SN, VIDList, [FLAG, QUES, IDAns]]};
                                        true ->
                                            {error, format_error}
                                    end;
                                true ->
                                    {error, length_error}
                            end;
                        16#8400 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                        16#8801 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
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
                        16#8804 ->
                            if
                                Len == 4 ->
                                    {"SN", SN} = get_specific_entry(Content, "SN"),
                                    {"LIST", List} = get_specific_entry(Content, "LIST"),
                                    {"DATA", {obj, DATA}} = get_specific_entry(Content, "DATA"),
                                    VIDList = get_same_key_list(List),
                                    DataLen = length(DATA),
                                    if
                                        DataLen == 4 ->
                                            {"CMD", CMD} = get_specific_entry(DATA, "CMD"),
                                            {"SF", SF} = get_specific_entry(DATA, "SF"),
                                            {"T", T} = get_specific_entry(DATA, "T"),
                                            {"FREQ", FREQ} = get_specific_entry(DATA, "FREQ"),
                                            {ok, Mid, [SN, VIDList, [CMD, T, SF, FREQ]]};
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
connect_ws_to_vdr(Msg) ->
    case Msg of
        {ok, Mid, Res} ->
            case Mid of
                16#8001 ->
                    ok;
                16#4001 ->
                    ok;
                16#4002 ->
                    ok;
                16#4003 ->
                    ok;
                16#8103 ->
                    [SN, VIDList, [ST, DT]] = Res,
                    SDT = ST ++ DT,
                    SDTBin = vdr_data_processor:create_set_term_args(length(SDT), SDT),
                    case SDTBin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8103, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8103, VIDList, SDTBin),
                            send_resp_to_ws(SN, 16#8103, VIDList, ?P_GENRESP_OK)
                    end;
                16#8203 ->
                    [SN, VIDList, [ASN, TYPE]] = Res,
                    Bin = vdr_data_processor:create_man_confirm_alarm(ASN, TYPE),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8203, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8203, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8203, VIDList, ?P_GENRESP_OK)
                    end;
                16#8602 ->
                    [SN, VIDList, FLAG, RECT] = Res,
                    Bin = vdr_data_processor:create_set_rect_area(FLAG, RECT),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8602, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8602, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8602, VIDList, ?P_GENRESP_OK)
                    end;
                16#8603 ->
                    [SN, VIDList, DataList] = Res,
                    case send_del_rect_areas_msg_to_vdr(VIDList, DataList) of
                        ok ->
                            send_resp_to_ws(SN, 16#8603, VIDList, ?P_GENRESP_OK);
                        _ ->
                            send_resp_to_ws(SN, 16#8603, VIDList, ?P_GENRESP_ERRMSG)
                    end;
                16#8105 ->
                    [SN, VIDList, CMDPAR] = Res,
                    case tuple_size(CMDPAR) of
                        1 ->
                            {CMD} = CMDPAR,
                            if
                                CMD > 2 andalso CMD < 8 ->
                                    Bin = vdr_data_processor:create_term_ctrl(CMD, ""),
                                    send_msg_to_vdrs(16#8105, VIDList, Bin),
                                    send_resp_to_ws(SN, 16#8105, VIDList, ?P_GENRESP_OK);
                                true ->
                                    send_resp_to_ws(SN, 16#8105, VIDList, ?P_GENRESP_ERRMSG)
                            end;
                        2 ->
                            {CMD, PAR} = CMDPAR,
                            if
                                CMD == 1 orelse CMD == 2 andalso is_list(PAR) ->
                                    Bin = vdr_data_processor:create_term_ctrl(CMD, PAR),
                                    send_msg_to_vdrs(16#8105, VIDList, Bin),
                                    send_resp_to_ws(SN, 16#8105, VIDList, ?P_GENRESP_OK);
                                true ->
                                    send_resp_to_ws(SN, 16#8105, VIDList, ?P_GENRESP_ERRMSG)
                            end;
                        _ ->
                            send_resp_to_ws(SN, 16#8105, VIDList, ?P_GENRESP_ERRMSG)
                    end;
                16#8202 ->
                    [SN, VIDList, [ITERVAL, LENGTH]] = Res,
                    Bin = vdr_data_processor:create_tmp_position_track_control(ITERVAL, LENGTH),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8202, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8202, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8202, VIDList, ?P_GENRESP_OK)
                    end;
                16#8300 ->
                    [SN, VIDList, [FLAG, TEXT]] = Res,
                    Bin = vdr_data_processor:create_txt_send(FLAG, TEXT),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8300, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8300, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8300, VIDList, ?P_GENRESP_OK)
                    end;
                16#8302 ->
                    [SN, VIDList, [FLAG, QUES, IDAns]] = Res,
                    QuesSize = byte_size(QUES),
                    Bin = vdr_data_processor:create_send_question(FLAG, QuesSize, QUES, IDAns),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8302, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8302, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8302, VIDList, ?P_GENRESP_OK),
                            update_vdrs_ws2vdr_msg_id_flowidx(16#8302, SN, VIDList, null)
                    end;
                16#8400 ->
                    [SN, VIDList, [FLAG, PHONE]] = Res,
                    Bin = vdr_data_processor:create_tel_callback(FLAG, PHONE),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8400, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8400, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8400, VIDList, ?P_GENRESP_OK)
                    end;
                16#8401 ->
                    [SN, VIDList, [TYPE, PhoneNameList]] = Res,
                    PNLen = length(PhoneNameList),
                    Bin = vdr_data_processor:create_tel_note(TYPE, PNLen, PhoneNameList),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8401, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8401, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8401, VIDList, ?P_GENRESP_OK)
                    end;
                16#8500 ->
                    [SN, VIDList, FLAG] = Res,
                    Bin = vdr_data_processor:create_car_con(FLAG),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8500, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8500, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8500, VIDList, ?P_GENRESP_OK),
                            update_vdrs_ws2vdr_msg_id_flowidx(16#8500, SN, VIDList, FLAG)
                    end;
                16#8801 ->
                    [SN, VIDList, [ID, CMD, T, SF, R, Q, B, CO, S, CH]] = Res,
                    Bin = vdr_data_processor:create_imm_photo_cmd(ID, CMD, T, SF, R, Q, B, CO, S, CH),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8801, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8801, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8801, VIDList, ?P_GENRESP_OK),
                            update_vdrs_ws2vdr_msg_id_flowidx(16#8801, SN, VIDList, null)
                    end;
                16#8804 ->
                    [SN, VIDList, [CMD, T, SF, FREQ]] = Res,
                    Bin = vdr_data_processor:create_record_start_order(CMD, T, SF, FREQ),
                    case Bin of
                        <<>> ->
                            send_resp_to_ws(SN, 16#8804, VIDList, ?P_GENRESP_ERRMSG);
                        _ ->
                            send_msg_to_vdrs(16#8804, VIDList, Bin),
                            send_resp_to_ws(SN, 16#8804, VIDList, ?P_GENRESP_OK)
                    end;
                _ -> % Impossible
                    ok
            end;
        _ ->
            ok
    end.

update_vdrs_ws2vdr_msg_id_flowidx(ID, FlowIdx, Value, VIDList) when is_integer(ID),
                                                                    is_integer(FlowIdx),
                                                                    is_list(VIDList),
                                                                    length(VIDList) > 0 ->
    [H|T] = VIDList,
    update_vdr_ws2vdr_msg_id_flowidx(ID, FlowIdx, Value, H),
    case T of
        [] ->
            ok;
        _ ->
            update_vdrs_ws2vdr_msg_id_flowidx(ID, FlowIdx, Value, T)
    end;
update_vdrs_ws2vdr_msg_id_flowidx(_ID, _FlowIdx, _Value, _VIDList) ->
    ok.

update_vdr_ws2vdr_msg_id_flowidx(ID, FlowIdx, Value, VID) when is_integer(ID),
                                                               is_integer(FlowIdx),
                                                               is_integer(VID) ->
    Res = ets:lookup(vdridsocktable, VID),
    case length(Res) of
        1 ->
            [VSock] = Res,
            MsgList = update_ws2vdrmsglist(VSock#vdridsockitem.msgws2vdr, ID, FlowIdx, Value),
            ets:insert(vdridsocktable, VSock#vdridsockitem{msgws2vdr=MsgList});
        _ ->
            ok
    end.

update_ws2vdrmsglist(List, ID, Value, FlowIdx) when is_integer(ID),
                                             is_integer(FlowIdx),
                                             is_list(List) ->
    NewList = [{OldID, OldFlowIdx, OldValue} || {OldID, OldFlowIdx, OldValue} <- List, OldID =/= ID],
    NewList ++ [{ID, FlowIdx, Value}];
update_ws2vdrmsglist(List, _ID, _Value, _FlowIdx) when is_list(List) ->
    List;
update_ws2vdrmsglist(_List, _ID, _Value, _FlowIdx) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_resp_to_ws(SN, ID, VIDList, Type) ->
    [{wspid, WSPid}] = ets:lookup(msgservertable, wspid),
    case wsock_data_parser:create_gen_resp(SN, ID, VIDList, Type) of
        {ok, WSResp} ->
            common:loginfo("WS Client : gateway send response for ws msg (~p) to WS (~p) : ~p~n", [ID, WSPid, WSResp]),
            Pid = self(),
            WSPid ! {Pid, WSResp},
            receive
                {Pid, wsok} ->
                    ok
            end;
       _ ->
            ok
    end.
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_del_rect_areas_msg_to_vdr(VIDList, DataList) when is_list(VIDList),
                                                       length(VIDList) > 0,
                                                       is_list(DataList),
                                                       length(DataList) > 125 ->
    {H, T} = lists:split(125, DataList),
    ResH = send_del_rect_areas_msg_to_vdr(VIDList, H),
    ResT = send_del_rect_areas_msg_to_vdr(VIDList, T),
    if
        ResH =/= ok orelse ResT =/= ok ->
            error;
        true ->
            ok
    end;
send_del_rect_areas_msg_to_vdr(VIDList, DataList) when is_list(VIDList),
                                                       length(VIDList) > 0,
                                                       is_list(DataList),
                                                       length(DataList) =< 125 ->
    Bin = vdr_data_processor:create_del_rect_area(length(DataList), DataList),
    case Bin of
        <<>> ->
            error;
        _ ->
            send_msg_to_vdrs(16#8603, VIDList, Bin)
    end;
send_del_rect_areas_msg_to_vdr(_VIDList, _DataList) ->
    error.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_msg_to_vdrs(ID, VDRList, Msg) when is_list(VDRList),
                                    length(VDRList) > 0,
                                    is_binary(Msg) ->
    [H|T] = VDRList,
    send_msg_to_vdr(ID, H, Msg),
    case T of
        [] ->
            ok;
        _ ->
            send_msg_to_vdrs(ID, T, Msg)
    end;
send_msg_to_vdrs(_ID, _VDRList, _Msg) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
send_msg_to_vdr(ID, VDR, Msg) when is_binary(Msg) ->
    VDRSockList = ets:lookup(vdridsocktable, VDR),
    case length(VDRSockList) of
        1 ->
            [VDRSock] = VDRSockList,
            common:loginfo("WS Server : Gateway WS delegation ~p sends msg to VDR (~p) : ~p~n", [self(), VDRSock#vdridsockitem.addr, Msg]),
            NewFlowIdx = vdr_handler:send_data_to_vdr(ID, VDRSock#vdridsockitem.msgflownum, Msg, VDRSock#vdridsockitem.vdrpid),
            ets:insert(vdridsocktable, VDRSock#vdridsockitem{msgflownum=NewFlowIdx});
        _ ->
            common:loginfo("WS Server : Cannot find VDRID in vdridsock table~n"),
            ok
    end;
send_msg_to_vdr(_ID, _VDR, _Msg) ->
    ok.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% List  :
% ID    : 
%
% Return    :
%       {ID, Value|null}
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_specific_entry(List, ID) when is_list(List) ->
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
                                    get_specific_entry(T, ID)
                            end
                    end;
                _ ->
                    get_specific_entry(T, ID)
            end
    end;
get_specific_entry(_List, ID) ->
    {ID, null}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% It can be use for the following similar list regardless of "VID", "ID" or the other key
%
% List  : [{obj, [{KEY:VALUE1}]}, {obj, [{KEY:VALUE2}]},...]
%
% Return    :
%       [Value1, Value2, ...]|[]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_same_key_list(List) when is_list(List),
                             length(List) > 0 ->
    [H|T] = List,
    {obj, [{_ID, Value}]} = H,
    [Value|get_same_key_list(T)];
get_same_key_list(_List) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
% List  : [{obj, [{KEY:VALUE1}]}, {obj, [{KEY:VALUE2}]},...]
%
% Return    :
%       [Value1, Value2, ...]|[]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_rect_area_list(List) when is_list(List),
                              length(List) > 0 ->
    [H|T] = List,
    {obj, DATA} = H,
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
    case T of
        [] ->
            [[ID, PROPERTY, LT_LAT, LT_LONG, RB_LAT, RB_LONG, ST, ET, MAX_S, LENGTH]];
        _ ->
        [[ID, PROPERTY, LT_LAT, LT_LONG, RB_LAT, RB_LONG, ST, ET, MAX_S, LENGTH]|get_rect_area_list(T)]
    end;
get_rect_area_list(_List) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% List  : [{obj,[{"ID",1},{"AN",<<"ANS1">>}]}, {obj,[{"ID",2},{"AN",<<"ANS2">>}, ...]
%
% Return    :
%       [[ID1, Ans1], [ID2, Ans2], ...]|[]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_answer_list(List) when is_list(List),
                           length(List) > 0 ->
    [H|T] = List,
    {obj, [{"ID", ID},{"AN", AN}]} = H,
    case T of
        [] ->
            [[ID, AN]];
        _ ->
            [[ID, AN]|get_answer_list(T)]
    end;
get_answer_list(_List) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_phone_name_list(List) when is_list(List),
                               length(List) > 0 ->
    [H|T] = List,
    {obj, DATA} = H,
    Len = length(DATA),
    if
        Len == 3 ->
            {"FLAG", FLAG} = get_specific_entry(DATA, "FLAG"),
            {"PHONE", PHONE} = get_specific_entry(DATA, "PHONE"),
            {"NAME", NAME} = get_specific_entry(DATA, "NAME"),
            case T of
                [] ->
                    [[FLAG, PHONE, NAME]];
                _ ->
                    [[FLAG, PHONE, NAME]|get_phone_name_list(T)]
            end;
        true ->
            case T of
                [] ->
                    [];
                _ ->
                    get_phone_name_list(T)
            end
    end;
get_phone_name_list(_List) ->
    [].
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% When WS need authencation, another initialization message will be used.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_init_msg() ->
    {ok, "{\"MID\":5, \"TOKEN\":\"anystring\"}"}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID       : 0x0001
% SN        : Response flow index, the same as the websocket message flow index
% SID       : Response ID, the same as the websocket message ID
% STATUS    : Result, 0 ~ 3
%               0   - success/ack
%               1   - failure
%               2   - message has error
%               3   - not supported
% List      : [ID0, ID1, ID2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_gen_resp(SN, SID, List, STATUS) when is_integer(SN), 
                                            is_integer(STATUS), 
                                            STATUS >= 0, 
                                            STATUS =< 3, 
                                            is_list(List) ->
    BoolSID = common:is_string(SID),
    if
        BoolSID ->
            VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
			Body = common:combine_strings(["\"MID\":1",
                                           "\"SN\":", integer_to_list(SN),
                                           "\"SID\":", SID,
                                           VIDListStr,
                                           "\"STATUS\":", integer_to_list(STATUS)]),
            {ok, common:combine_strings(["{", Body, "}"], false)};
        true ->
            error
    end;
create_gen_resp(_SN, _SID, _List, _STATUS) ->
    error.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0002
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_pulse() ->
    {ok, "{\"MID\":2}"}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0003
%
% Parmeter
%   List    : [ID0, ID1, ID2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_term_online(List) ->
    MIDStr = "\"MID\":3",
    VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
	Body = common:combine_strings([MIDStr, VIDListStr]),
    {ok, common:combine_strings(["{", Body, "}"], false)}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0004
%
% Parameter
%   List    : [ID0, ID1, ID2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_term_offline(List) ->
    MIDStr = "\"MID\":4",
    VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
	Body = common:combine_strings([MIDStr, VIDListStr]),
    {ok, common:combine_strings(["{", Body, "}"], false)}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0005
%
% Parameter
%   Token   : it must be string
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_authen(Token) ->
    MIDStr = "\"MID\":5",
    case common:is_string(Token) of
        true ->
            {ok, common:combine_strings(["{", MIDStr, "\"TOKEN\":", Token, "}"], false)};
        _ ->
            {ok, common:combine_strings(["{", MIDStr, "\"TOKEN\":\"\"", "}"], false)}
    end.            

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0200
%
% Parameter
%   List    : [ID0, ID1, ID2, ...]
%   SN      : message flow index
%   CODE    : vehicle code
%   AF
%   SF
%   Lat
%   Long
%   T
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_term_alarm(List, SN, Code, AF, SF, Lat, Long, T) when is_integer(SN)->
    MIDStr = "\"MID\":512",
    SNStr = string:concat("\"SN\":", integer_to_list(SN)),
    VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
    DataListStr = common:combine_strings(["\"DATA\":{",  create_list(["\"CODE\"", "\"AF\"", "\"SF\"", "\"LAT\"", "\"LONG\"", "\"T\""], [Code, AF, SF, Lat/1000000.0, Long/1000000.0, T], true), "}"], false),
    Body = common:combine_strings([MIDStr, SNStr, VIDListStr, DataListStr]),
    {ok, common:combine_strings(["{", Body, "}"], false)};
create_term_alarm(_List, _SN, _Code, _AF, _SF, _Lat, _Long, _T) ->
    error.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0302
%
% SN        :
% List      : VDR list
% IDList    : Answer ID list
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_term_answer(SN, List, IDList) ->
    if
        is_integer(SN) ->
            MIDStr = "\"MID\":770",
            SNStr = string:concat("\"SN\":", integer_to_list(SN)),
            VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
            DataListStr = common:combine_strings(["\"DATA\":{",  create_list(["\"ID\""], IDList, true), "}"], false),
			Body = common:combine_strings([MIDStr, SNStr, VIDListStr, DataListStr]),
            {ok, common:combine_strings(["{", Body, "}"], false)};
        true ->
            error
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0500
%
% SN        :
% Status    :
% List      : VDR list
% DataList  : Data list
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_vehicle_ctrl_answer(SN, Status, List, DataList) when is_integer(SN),
                                                            is_integer(Status),
                                                            Status >= 0,
                                                            Status =< 3 ->
    MIDStr = "\"MID\":1280",
    SNStr = string:concat("\"SN\":", integer_to_list(SN)),
    StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
    VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
    case Status of
        1 ->
            DataListStr = common:combine_strings(["\"DATA\":{",  create_list(["\"FLAG\""], DataList, true), "}"], false),
			Body = common:combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr]),
            {ok, common:combine_strings(["{", Body, "}"], false)};
        _ ->
            DataListStr = "\"DATA\":{}",
			Body = common:combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr]),
            {ok, common:combine_strings(["{", Body, "}"], false)}
    end;
create_vehicle_ctrl_answer(_SN, _Status, _List, _DataList) ->
    error.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% MID   : 0x0805
%
% SN        :
% List      : VDR list
% Status    :
% Data      : ID list
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_shot_resp(SN, List, Status, IDList) when is_integer(SN),
                                                is_integer(Status),
                                                Status >= 0,
                                                Status =< 3 ->
    MIDStr = "\"MID\":2053",
    SNStr = string:concat("\"SN\":", integer_to_list(SN)),
    VIDListStr = common:combine_strings(["\"LIST\":[",  create_list(["\"VID\""], List, false), "]"], false),
    StatusStr = string:concat("\"STATUS\":", integer_to_list(Status)),
    case Status of
        0 ->
            DataListStr = common:combine_strings(["\"DATA\":[",  create_list(["\"ID\""], IDList, false), "]"], false),
			Body = common:combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr]),
            {ok, common:combine_strings(["{", Body, "}"], false)};
        _ ->
            DataListStr = "\"DATA\":[]",
			Body = common:combine_strings([MIDStr, SNStr, StatusStr, VIDListStr, DataListStr]),
            {ok, common:combine_strings(["{", Body, "}"], false)}
    end;
create_shot_resp(_SN, _List, _Status, _IDList) ->
    error.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%   When IsOne == true, the result is like : "A":XA,"B":XB,"C":XC,...
%   When IsOne == false, the result is like : {"A":XA},{"B":XB},{"C":XC},...
%
%   Currently,
%       1. IDList can only accept string, like ["A", "B", "C", ...] or ["A"]
%       2. List can only accept integer, float or string
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_list(IDList, List, IsOne) when is_list(IDList),
                                      is_list(List), 
                                      is_boolean(IsOne), 
                                      length(IDList) > 0, 
                                      length(List) > 0 ->
    IDListLen = length(IDList),
    ListLen = length(List),
    Bool = common:is_string_list(IDList),
    if
        Bool == true ->
            if
                IDListLen == 1 ->
                    [ID] = IDList,
                    [Val|T] = List,
                    case convert_variable_to_list(Val) of
                        {ok, SVal} ->
                            case T of
                                [] ->
                                    case IsOne of
                                        true ->
                                            common:combine_strings([ID, ":", SVal], false);
                                        _ ->
                                            common:combine_strings(["{", ID, ":", SVal, "}"], false)
                                        end;
                                _ ->
                                    case IsOne of
                                        true ->
                                            common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDList, T, IsOne)]), false);
                                        _ ->
                                            common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDList, T, IsOne)]), false)
                                    end
                            end;
                        error ->
                            case T of
                                [] ->
                                    [];
                                _ ->
                                    create_list(IDList, T, IsOne)
                            end
                    end;
                IDListLen > 1 ->
                    if
                        IDListLen =/= ListLen ->
                            [];
                        true ->
                            [ID|IDTail] = IDList,
                            [Val|ValTail] = List,
                            case convert_variable_to_list(Val) of
                                {ok, SVal} ->
                                    case ValTail of
                                        [] ->
                                            case IsOne of
                                                true ->
                                                    common:combine_strings([ID, ":", SVal], false);
                                                _ ->
                                                    common:combine_strings(["{", ID, ":", SVal, "}"], false)
                                                end;
                                        _ ->
                                            case IsOne of
                                                true ->
                                                    common:combine_strings(lists:append([ID, ":", SVal, ","], [create_list(IDTail, ValTail, IsOne)]), false);
                                                _ ->
                                                    common:combine_strings(lists:append(["{", ID, ":", SVal, "},"], [create_list(IDTail, ValTail, IsOne)]), false)
                                            end
                                    end;
                                error ->
                                    case ValTail of
                                        [] ->
                                            [];
                                        _ ->
                                            create_list(IDTail, ValTail, IsOne)
                                    end
                            end
                    end
            end;
        true ->
            []
    end;
create_list(_IDList, _List, _IsOne) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Convert integer/float/string to string
%
% Return    :
%       {ok, string}
%       error
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_variable_to_list(Variable) when is_integer(Variable) ->
    {ok, integer_to_list(Variable)};
convert_variable_to_list(Variable) when is_float(Variable) ->
    {ok, float_to_list(Variable)};
convert_variable_to_list(Variable) when is_list(Variable) ->
    case common:is_string(Variable) of
        true ->
            {ok, Variable};
        _ ->
            error
    end;
convert_variable_to_list(_Variable) ->
    error.



