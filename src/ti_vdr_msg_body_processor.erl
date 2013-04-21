%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%
%%% Abbr:
%%%     resp    - response
%%%     gen     - general
%%%     pos     - position
%%%     rect    - rectangle
%%%     rnd     - round
%%%     poly    - polygon
%%%     mmedia  - multimedia
%%%     rec     - record
%%%     idx     - index
%%%     res     - result
%%%     msg     - message
%%%     err     - error
%%%     ori     - original
%%%     lic     - License
%%%     term    - terminal
%%%     auth    - authentication
%%%

-module(ti_vdr_msg_body_processor).

-include("ti_header.hrl").

-export([parse_msg_body/2]).

-export([create_general_response/3, 
         create_resend_subpack_req/3,
         create_reg_resp/3,
	     create_set_term_args/2,
         create_term_query_args/0,
         create_query_specific_term_args/2,
         create_term_ctrl/2,
         create_query_term_property/0,
         create_update_packet/6,
         create_position_search/0,
         create_tmp_position_track_control/2,
         create_man_confirm_alarm/2,
         create_txt_send/2,
         create_set_event/3,
         create_send_question/4,
         create_msgmenu_settings/3,
         create_msg_service/3,
         create_tel_callback/2,
         create_tel_note/3,
         create_car_con/1,
         create_set_circle_area/11,
         create_del_circle_area/2,
         create_set_rect_area/3,
         create_del_rect_area/2,
         create_set_polygon_area/8,
         create_del_polygon_area/2,
         create_set_lines/6,
         create_del_lines/2,
         create_record_collect_cmd/2,
         create_record_args_send/2,
         create_report_driver_id_request/0,
         create_multimedia_data_reply/3,
         create_imm_photo_cmd/10,
         create_stomuldata_search/5,
         create_stomuldata_update/6,
         create_record_start_order/4,
         create_sinstomuldatasea_update_order/2,
         create_data_dl_transparent/2,
         %create_data_ul_send/2,         
         create_platform_rsa/2
	]).

%%%
%%% Parse terminal message body
%%% Return :
%%%     {ok, Result}            - Result is a complex list, such as [[...],[...],[...],...]
%%%     {error, msgerr}
%%%     {error, unsupported}
%%%
parse_msg_body(ID, Body) ->
    try do_parse_msg_body(ID, Body)
    catch
        _:Exception ->
            ti_common:logerror("do_parse_msg_body(ID=~p, Body) exception : ~p~n", [ID, Exception]),
            {error, msgerr}
    end.

%%%
%%% Internal method for parse_msg_body(ID, Body)
%%%
do_parse_msg_body(ID, Body) ->
    case ID of
        16#1    ->                          
            parse_gen_resp(Body);
        16#2    ->                          
            parse_pulse(Body);
        16#100  ->                          
            parse_reg(Body);
        16#3    ->                          
            parse_unreg(Body);
        16#102  ->                          
            parse_check_auth(Body);
        16#104  ->                          
            parse_query_term_args_response(Body);
        16#107  ->                      
            parse_query_term_prop_response(Body);
        16#108  ->                          
            parse_update_result_notification(Body);
        16#200  ->                      
            parse_position_info_report(Body);
        16#201  ->                          
            parse_query_position_response(Body);
        16#301  ->                          
            parse_event_report(Body);
        16#302  ->
            parse_question_resp(Body);
        16#303  ->
            parse_msg_proorcancel(Body);
        16#500  ->
            parse_car_con_response(Body);
        16#700  ->
            parse_record_upload(Body);
        16#701  ->
            parse_electron_invoice_report(Body);
        16#702  ->
            parse_driver_id_report(Body);
        16#704  ->
            parse_position_data_batch_update(Body);
        16#705  ->
            parse_CAN_data_update(Body);
        16#800  ->
            parse_multi_media_event_update(Body);
        16#801  ->
            parse_multi_media_data_update(Body);
        16#802  ->
            parse_stomuldata_response(Body);
        16#805  ->
            parse_imm_photo_cmd_response(Body);
        16#900  ->
            parse_data_ul_transparent(Body);
        16#901  ->
            parse_data_compress_update(Body);
        16#a00  ->
            parse_term_rsa(Body);
        _ ->
            {error, unsupported}
    end.

%%%
%%% 0x0001
%%% Terminal general response
%%%     RespIdx : WORD
%%%     RespID  : WORD
%%%     Res     : BYTE
%%%                 0   - SUCCESS/ACK
%%%                 1   - FAIL
%%%                 2   - MSG ERR
%%%                 3   - NOT SUPPORTED
%%%
parse_gen_resp(Bin) ->
    Len = bit_size(Bin),
    if
        Len == (5 * ?LEN_BYTE) ->
            <<RespIdx:?LEN_WORD, ID:?LEN_WORD, Res:?LEN_BYTE>> = Bin,
            if
                Res > 3 ->
                    {error, msgerr};
                Res < 0 ->
                    {error, msgerr};
                true ->
                    {ok, {RespIdx, ID, Res}}
            end;
        Len =/=(5 * ?LEN_BYTE) ->
            {error, msgerr}
    end.

%%%
%%% 0x0801
%%% Platform general response
%%%     RespIdx : WORD
%%%     RespID  : WORD
%%%     Resp    : BYTE
%%%                 0 - SUCCESS/ACK
%%%                 1 - FAIL
%%%                 2 - MSG ERR
%%%                 3 - NOT SUPPORTED
%%%                 4 - ALARM ACK
%%%
create_general_response(FlowIdx, ID, Resp) ->
    if
        Resp < 0 ->
            error;
        Resp > 4 ->
            error;
        true ->
            {ok, <<FlowIdx:?LEN_WORD, ID:?LEN_WORD, Resp:?LEN_BYTE>>}
    end.

%%%
%%% 0x0002
%%% Terminal pulse
%%% 
parse_pulse(_Bin) ->
    {ok, {}}.

%%%
%%% 0x0803
%%% Platform sub-package resending request
%%%     OriMsgIdx   : WORD      - The index of the first sub-package of the original message
%%%     Count       : BYTE(n)   - The count of the whole sub-packages which are needed to be resent.
%%%     IDList      : BYTE(2*n) - [ID0, ID1, ID2, ID3, ...]
%%%
create_resend_subpack_req(FlowIdx, Count, IDList) ->
    Bin = list_to_binary([<<X:?LEN_WORD>> || X <- IDList]),
    Len = length(IDList),
    if
        Len == Count ->
            {ok, <<FlowIdx:?LEN_WORD, Len:?LEN_BYTE, Bin/binary>>};
        true ->
            error
    end.

%%%
%%% 0x0100
%%% Terminal registration
%%%     Province    : WORD
%%%     City        : WORD
%%%     Producer ID : BYTE[5]
%%%     Term Model  : BYTE[20]
%%%     Term ID     : BYTE[7]
%%%     Lic Color   : BYTE
%%%     Lic ID      : STRING
%%%
parse_reg(Bin) ->
    Len = bit_size(Bin),
    if
        Len =< ((2+2+5+20+7+1)*?LEN_BYTE) ->
            {error, msgerr};
        true ->
            <<Province:?LEN_WORD, City:?LEN_WORD, Producer:(5*?LEN_BYTE), TermModel:(20*?LEN_BYTE), TermID:(7*?LEN_BYTE), LicColor:?LEN_BYTE, Tail/binary>> = Bin,
            LicID = binary_to_list(Tail),
            {ok, {Province, City, Producer, TermModel, TermID, LicColor, LicID}}
    end.

%%%
%%% 0x8100
%%%     RespIdx     : WORD
%%%     Res         : BYTE
%%%                     0   - OK
%%%                     1   - VEHICLE ALREADY REGISTERED
%%%                     2   - NO SUCH VEHICLE IN DATABASE
%%%                     3   - TERM ALREADY REGISTERED
%%%                     4   - NO SUCH TERM IN DATABASE
%%%     AuthCode    : STRING
%%%
create_reg_resp(RespIdx, Res, AuthCode) ->
    if
        Res < 0 ->
            error;
        Res > 4 ->
            error;
        true ->
            Bin = list_to_binary(AuthCode),
            {ok, <<RespIdx:?LEN_WORD, Res:?LEN_WORD, Bin/binary>>}
    end.

%%%
%%% 0x0003
%%% Terminal unregistation
%%%
parse_unreg(_Bin) ->
    {ok, {}}.

%%%
%%% 0x0102
%%%     Auth    : STRING
%%%
parse_check_auth(Bin) ->
    Len = bit_size(Bin),
    if
        Len < 1 ->
            {error, msgerr};
        true ->
            Auth = binary_to_list(Bin),
            {ok, {Auth}}
    end.

%%%
%%% 0x8103
%%%     Count   : BYTE
%%%     ArgList : [[ID0, Value0], [ID1, Value1], [ID2, Value2], ...]
%%%               T-L-V : DWORD-BYTE-L*8
%%%
create_set_term_args(Count, ArgList) ->
    Len = length(ArgList),
    if
        Len == Count ->
            Bin = list_to_binary([compose_term_args_binary(ID, Value) || [ID, Value] <- ArgList]),
            {ok, <<Len:?LEN_BYTE,Bin/binary>>};
        true ->
            error
    end.

%%%
%%% ActLen should be bit_size or byte_size ?????
%%% Currently using byte_size
%%% Has better format?
%%%
compose_term_args_binary(ID, Value) ->
    Len = bit_size(Value),
    if
        Len < 1 ->
            if
                ID > 16#7, ID =< 16#F ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#1D, ID =< 16#1F ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#22, ID =< 16#26 ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#29, ID =< 16#2B ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#31, ID =< 16#3F ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#49, ID =< 16#4F ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#5E, ID =< 16#63 ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#65, ID =< 16#6F ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#74, ID =< 16#7F ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID > 16#F000, ID =< 16#FFFF ->
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                true ->
                    <<>>
            end;
        true ->
            if
                ID >= 16#0, ID =< 16#7 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#8, ID =< 16#F ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#10, ID =< 16#17 ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
                ID >= 16#18, ID =< 16#19 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#1A ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
                ID >= 16#1B, ID =< 16#1C ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#1D ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
                ID >= 16#1E, ID =< 16#1F ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#20, ID =< 16#22 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#23, ID =< 16#26 ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#27, ID =< 16#29 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#2A, ID =< 16#2B ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#2C, ID =< 16#30 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#31 ->
                    ActLen = ?LEN_WORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#32, ID =< 16#3F ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#40, ID =< 16#44 ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
                ID >= 16#45, ID =< 16#47 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#48, ID =< 16#49 ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
                ID >= 16#4A, ID =< 16#4F ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#50, ID =< 16#5A ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#5B, ID =< 16#5E ->
                    ActLen = ?LEN_WORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#5F, ID =< 16#63 ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#64, ID =< 16#65 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#66, ID =< 16#6F ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID >= 16#70, ID =< 16#74 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#75, ID =< 16#7F ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                ID == 16#80 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#81, ID =< 16#82 ->
                    ActLen = ?LEN_WORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#83 ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
                ID == 16#84 ->
                    ActLen = ?LEN_BYTE_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#90, ID =< 16#92 ->
                    ActLen = ?LEN_BYTE_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#93 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#94 ->
                    ActLen = ?LEN_BYTE_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#95 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#100 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#101 ->
                    ActLen = ?LEN_WORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#102 ->
                    ActLen = ?LEN_DWORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID == 16#103 ->
                    ActLen = ?LEN_WORD_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#110, ID =< 16#1FF ->
                    ActLen = 8*?LEN_BYTE_BYTE,
                    <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
                ID >= 16#F000, ID =< 16#FFFF ->                    % Impossible, the same to the other items whose length is 0.
                    <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
                true ->
                    <<>>
            end
    end.


%%%
%%% 0x8104
%%%
create_term_query_args() ->
    {ok, <<>>}.

%%%
%%% 0x8106
%%%     Count   : BYTE(n)
%%%     IDList  : BYTE[4*n]
%%%                 [ID0, ID1, ID2, ...]
%%%
create_query_specific_term_args(Count, IDList) ->
    Len = length(IDList),
    if
        Count == Len ->
            Bin = list_to_binary([<<ID:?LEN_DWORD>> || [ID] <- IDList]),
            {ok,<<Len:8,Bin/binary>>};
        true ->
            error
    end.

%%%
%%% 0x0104
%%% Result:
%%%     RespIdx : WORD
%%%     Count   : BYTE
%%%     ArgList : [[ID0, Value0], [ID1, Value1], [ID2, Value2], ...]
%%%               T-L-V : DWORD-BYTE-L*8
%%%
%%% Len should be byte_size or bit_size????
%%% Currently using byte_size
%%%
parse_query_term_args_response(Bin) ->
    Len = length(Bin),
    if
        Len =< ((2+1)*?LEN_BYTE) ->
            {error, msgerr};
        true ->
            <<RespIdx:?LEN_WORD, Count:?LEN_BYTE, Tail/binary>> = Bin,
            List = extract_term_args_resp(Tail),
            ActLen = length(List),
            if
                ActLen == Count ->
                    {ok, {RespIdx, ActLen, List}};
                true ->
                    {error, msgerr}
            end
    end.

%%%
%%% Len should be byte_size or bit_size????
%%% Currently using byte_size
%%%
extract_term_args_resp(Bin) ->
    Len = bit_size(Bin),
    if
        Len < ((4+1)*?LEN_BYTE) ->
            [];
        true ->
            <<ID:?LEN_DWORD, Len:?LEN_BYTE, Tail/binary>> = Bin,
            TailLen = bit_size(Tail),
            if
                Len > TailLen ->
                    [];
                Len =< TailLen ->
                    {Bin0, Bin1} = split_binary(Tail, Len*?LEN_BYTE),
                    Arg =  convert_term_args_binary(ID, Len, Bin0),
                    [Arg|extract_term_args_resp(Bin1)]
            end
    end.

%%%
%%% Len should be byte_size or bit_size????
%%% Currently using byte_size
%%% Has better format?
%%%
convert_term_args_binary(ID, Len, Bin) ->
    if
        ID >= 16#0, ID =< 16#7 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#8, ID =< 16#F ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#10, ID =< 16#17 ->
            ActLen = byte_size(Bin),
            if
                ActLen == Len ->
                    Str = binary_to_list(Bin),
                    [ID, Len, Str];
                true ->
                    []
            end;
        ID >= 16#18, ID =< 16#19 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#1A ->
            ActLen = byte_size(Bin),
            if
                ActLen == Len ->
                    Str = binary_to_list(Bin),
                    [ID, Len, Str];
                true ->
                    []
            end;
        ID >= 16#1B, ID =< 16#1C ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#1D ->
            ActLen = byte_size(Bin),
            if
                ActLen == Len ->
                    Str = binary_to_list(Bin),
                    [ID, Len, Str];
                true ->
                    []
            end;
        ID >= 16#1E, ID =< 16#1F ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#20, ID =< 16#22 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#23, ID =< 16#26 ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#27, ID =< 16#29 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#2A, ID =< 16#2B ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#2C, ID =< 16#30 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#31 ->
            if
                Len == ?LEN_WORD_BYTE ->
                    <<Value:?LEN_WORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#32, ID =< 16#3F ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#40, ID =< 16#44 ->
            ActLen = byte_size(Bin),
            if
                ActLen == Len ->
                    Str = binary_to_list(Bin),
                    [ID, Len, Str];
                true ->
                    []
            end;
        ID >= 16#45, ID =< 16#47 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#48, ID =< 16#49 ->
            ActLen = byte_size(Bin),
            if
                ActLen == Len ->
                    Str = binary_to_list(Bin),
                    [ID, Len, Str];
                true ->
                    []
            end;
        ID >= 16#4A, ID =< 16#4F ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#50, ID =< 16#5A ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#5B, ID =< 16#5E ->
            if
                Len == ?LEN_WORD_BYTE ->
                    <<Value:?LEN_WORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#5F, ID =< 16#63 ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#64, ID =< 16#65 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#66, ID =< 16#6F ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID >= 16#70, ID =< 16#74 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#75, ID =< 16#7F ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        ID == 16#80 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#81, ID =< 16#82 ->
            if
                Len == ?LEN_WORD_BYTE ->
                    <<Value:?LEN_WORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#83 ->
            ActLen = byte_size(Bin),
            if
                ActLen == Len ->
                    Str = binary_to_list(Bin),
                    [ID, Len, Str];
                true ->
                    []
            end;
        ID == 16#84 ->
            if
                Len == ?LEN_BYTE_BYTE ->
                    <<Value:?LEN_BYTE>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#90, ID =< 16#92 ->
            if
                Len == ?LEN_BYTE_BYTE ->
                    <<Value:?LEN_BYTE>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#93 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#94 ->
            if
                Len == ?LEN_BYTE_BYTE ->
                    <<Value:?LEN_BYTE>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#95 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#100 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#101 ->
            if
                Len == ?LEN_WORD_BYTE ->
                    <<Value:?LEN_WORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#102 ->
            if
                Len == ?LEN_DWORD_BYTE ->
                    <<Value:?LEN_DWORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID == 16#103 ->
            if
                Len == ?LEN_WORD_BYTE ->
                    <<Value:?LEN_WORD>> = Bin,
                    [ID, Len, Value];
                true ->
                    []
            end;
        ID >= 16#110, ID =< 16#1FF ->
            ActLen = 8*?LEN_BYTE_BYTE,
            [ID, ActLen, Bin];
        ID >= 16#F000, ID =< 16#FFFF ->
            if
                Len == 0 ->
                    [ID, 0, []];
                true ->
                    []
            end;
        true ->
            []
    end.    

%%%
%%% 0x8105
%%% CmdType : BYTE
%%% CmdArg  : STRING
%%%
create_term_ctrl(Type, Arg) ->
    if
        Type >= 1, Type =< 2 ->
            Bin = list_to_binary(Arg),
            {ok, <<Type:8, Bin/binary>>};
        Type >=3, Type =< 7 ->
            {ok, <<Type:8>>};
        true ->
            error
    end.
    %case Type of
    %    1 ->
    %        List = re:split(Args, ";", [{return, list}]),
    %        Bin = list_to_binary(List),
    %        <<Type:8,Bin/binary>>;
    %    2 ->
    %        List = re:split(Args, ";", [{return, list}]),
    %        Bin = list_to_binary(List),
    %        <<Type:8,Bin/binary>>;
    %    _ ->
    %        <<Type:8>>
    %end.

%%%
%%% 0x8107
%%%
create_query_term_property() ->
    {ok, <<>>}.

%%%
%%% 0x0107
%%%
parse_query_term_prop_response(Bin) ->
    Len = byte_size(Bin),
    if
        Len < (2+5+20+7+10+1+1+1+1+2) ->       % The last 2 is for HwVer and FwVer
            {error,msgerr};
        true ->
            <<Type:?LEN_WORD, ProId:(5*?LEN_BYTE), Model:(20*?LEN_BYTE), TerId:(7*?LEN_BYTE), ICCID:(10*?LEN_BYTE), HwVerLen:?LEN_BYTE, Tail0/binary>> = Bin,
            HwVerBinLen = ?LEN_BYTE*HwVerLen,
            Len0 = byte_size(Tail0),
            if
                Len0 < (HwVerLen+1+1+1+1) ->   % The last 1 is for FwVer
                    {error, msgerr};
                true ->
                    <<HwVer:HwVerBinLen, FwVerLen:?LEN_BYTE, Tail1/binary>> = Tail0,
                    FwVerBinLen = ?LEN_BYTE*FwVerLen,
                    Len1 = byte_size(Tail1),
                    if
                        Len1 < (FwVerLen+1+1) ->
                            <<FwVer:FwVerBinLen, GNSS:?LEN_BYTE, Prop:?LEN_BYTE>> = Tail1,
                            {ok, {Type, ProId, Model, TerId, ICCID, HwVerLen, HwVer, FwVerLen, FwVer, GNSS, Prop}};
                        true ->
                            {error, msgerr}
                    end
            end
    end.

%%%
%%% 0x8108
%%% Type        : BYTE
%%% ProID       : BYTE[5]
%%% VerLen      : BYTE
%%% Ver         : STRING
%%% UpgradeLen  : DWORD
%%% UpgradeData :
%%%
%%% I don't know whether it is correct to process BYTE[n] by list_to_binary
%%%
create_update_packet(Type, ProID, VerLen, Ver, UpgradeLen, UpgradeData) ->
    Len0 = length(Ver),
    if
        VerLen =/= Len0 ->
            error;
        true ->
            Len1 = byte_size(UpgradeData),
            if
                Len1 =/= UpgradeLen ->
                    error;
                true ->
                    %ProIDBin = list_to_binary(ProID),
                    VerBin = list_to_binary(Ver),
                    %UpgradeDataBin = list_to_binary(UpgradeData),
                    Bin = list_to_binary([<<Type:?LEN_BYTE>>, ProID, <<VerLen:?LEN_BYTE>>, VerBin, <<UpgradeLen:?LEN_DWORD>>, UpgradeData]),
                    {ok, Bin}
            end
    end.

%%%
%%% 0x0108
%%%
parse_update_result_notification(Bin) ->
    Len = byte_size(Bin),
    if
        Len == 2 ->
            <<Type:?LEN_BYTE, Res:?LEN_BYTE>> = Bin,
            if
                Res >= 0, Res =< 2 ->
                    case Type of
                        0 ->
                            {ok, {Type, Res}};
                        12 ->
                            {ok, {Type, Res}};
                        52 ->
                            {ok, {Type, Res}};
                        _ ->
                            {error, msgerr}
                    end;
                true ->
                    {error, msgerr}
            end;
        true ->
            {error, msgerr}
    end.

%%%
%%%  Not completed here.
%%%

%%%
%%% 0x0200
%%% Appended Information is a list, we should parse it here!!!
%%%
parse_position_info_report(Bin) ->
    Len = byte_size(Bin),
    if
        Len < (4+4+4+4+2+2+2+6) ->
            {error, msgerr};
        true ->
            <<AlarmSym:?LEN_DWORD, State:?LEN_DWORD, Lat:?LEN_DWORD, Lon:?LEN_DWORD, Height:?LEN_WORD, Speed:?LEN_WORD, Direction:?LEN_WORD, Time:(6*?LEN_BYTE), Tail/binary>> = Bin,
            H = [AlarmSym, State, Lat, Lon, Height, Speed, Direction, Time],
            Len = byte_size(Tail),
            if
        	    Len > 0 ->
                    AppInfo = get_appended_info(Tail),
                    case AppInfo of
                        error ->
                            {error, msgerr};
                        [] ->
                            {ok, {H}};
                        _ ->
                            {ok, {H, AppInfo}}
                    end;
                    %<<AppID:?LEN_BYTE, AppLen:?LEN_BYTE, AppMsg/binary>> = Tail,
                    %Len0 = byte_size(AppMsg),
                    %if
                    %    Len0 == AppLen ->
                    %        {ok, {H, [AppID, AppLen, AppMsg]}};
                    %    true ->
                    %        {error, msgerr}
                    %end;
                Len == 0 ->
                    {ok, {H}}
            end
    end.

get_appended_info(Bin) ->
    Len = byte_size(Bin),
    if
        Len < 2 ->
            [];
        true ->
            <<ID:?LEN_BYTE, Len:?LEN_BYTE, Tail0/binary>> = Bin,
            case ID of
                16#1 ->
                    if
                        Len == 4 ->
                            ok;
                        true ->
                            error
                    end;
                _ ->
                    error
            end
    end.

%%%
%%% 0x8201
%%%
create_position_search() ->
    <<>>.

%%%
%%% 0x0201
%%%
parse_query_position_response(Bin) ->       
    <<RespNum:16,PosMsgResp/binary>> = Bin,
    {ok, {PosMsg}} = parse_position_info_report(PosMsgResp),
    {ok, {RespNum, PosMsg}}.

%%%
%%% 0x8202
%%%
create_tmp_position_track_control(Interval, PosTraValidity) ->
    <<Interval:16,PosTraValidity:32>>.

%%%
%%% 0x8203
%%%
create_man_confirm_alarm(Number,Type) ->
    <<Number:16,Type:32>>.

%%%
%%% 0x8300
%%%
create_txt_send(Symbol,TextMsg) ->
    TM = list_to_binary(TextMsg),
    <<Symbol:8,TM/binary>>.

%%%
%%% 0x8301
%%% Events : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%%%
create_set_event(Type,_Count,Events) ->
    Len = length(Events),
    EventsBin = get_event_binary(Events, 8, 8),
    <<Type:8,Len:8,EventsBin/binary>>.

get_event_binary(Events, IDLen, LenLen) ->
    case Events of
        [] ->
            <<>>;
        _ ->
            [H|T] = Events,
            {ID,Len,Con} = H,
            case T of
                [] ->
                    <<ID:IDLen,Len:LenLen,Con/binary>>;
                _ ->
                    [<<ID:IDLen,Len:LenLen,Con/binary>>|get_event_binary(T, IDLen, LenLen)]
            end
    end.

%%%
%%% 0x0301
%%%
parse_event_report(Bin) ->
    <<Id:8>> = Bin,
    {ok,{Id}}.

%%%
%%% 0x8302
%%% Answers : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%%%
create_send_question(Symbol,QueLen,Que,Answers) -> 
    Q = term_to_binary(Que),
    Ans = get_event_binary(Answers, 8, 16),
    <<Symbol:8,QueLen:8,Q/binary,Ans/binary>>.

%%%
%%% 0x0302
%%%
parse_question_resp(Bin) ->
    <<Number:16,Id:8>> = Bin,
    {ok,{Number,Id}}.

%%%
%%% 0x8303
%%% Msgs : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%%%
create_msgmenu_settings(SetType,_Count,Msgs) ->
    Len = length(Msgs),
    MsgsBin = get_event_binary(Msgs, 8, 16),
    <<SetType:8,Len:8,MsgsBin/binary>>.

%%%
%%% 0x0303
%%%
parse_msg_proorcancel(Bin) ->
    <<MsgType:8,POC:8>> = Bin,
    {ok,{MsgType,POC}}.

%%%
%%% 0x8304
%%%
create_msg_service(Type,Len,Con) ->
    ConBin = term_to_binary(Con),
    <<Type:8,Len:16,ConBin/binary>>.

%%%
%%% 0x8400
%%%
create_tel_callback(Symbol,Number) ->
    Len = length(Number),
    if
        Len > 20 ->
            {Num0, _Num1} = lists:split(20, Number),
            N = list_to_binary(Num0),
            <<Symbol:8,N/binary>>;
        Len =< 20 ->
            N = list_to_binary(Number),
            <<Symbol:8,N/binary>>
    end.

%%%
%%% 0x8401
%%%
create_tel_note(Type,_Count,Items) ->
    Len = length(Items),
    ItemsBin = get_tel_book_entries(Items),
    <<Type:8,Len:8,ItemsBin/binary>>.

get_tel_book_entries(Items) ->
    case Items of
        [] ->
            <<>>;
        _ ->
            [H|T] = Items,
            {Flag,NumLen,Num,NameLen,Name} = H,
            case T of
                [] ->
                    <<Flag:8,NumLen:8,Num/binary,NameLen:8,Name/binary>>;
                _ ->
                    [<<Flag:8,NumLen:8,Num/binary,NameLen:8,Name/binary>>|get_tel_book_entries(T)]
            end
    end.
    
%%%
%%% 0x8500
%%%
create_car_con(Symbol) ->
    <<Symbol:8>>.

%%%
%%% 0x0500
%%% Definition is not complete in document.
%%%
parse_car_con_response(Msg) ->
    <<FlowNum:16,M/binary>> = Msg,
    {ok, Resp} = parse_position_info_report(M),
    {ok,{FlowNum, Resp}}.

%%%
%%% 0x8600
%%%
create_set_circle_area(SetArr,AreaCount,AreaId,AreaArr,Latitude,Longitude,Radius,Stime,Etime,Hspeed,OSTime) ->
    St = list_to_binary(Stime),
    Et = list_to_binary(Etime),
    <<SetArr:8,AreaCount:8,AreaId:32,AreaArr:16,Latitude:32,Longitude:32,Radius:32,St:48,Et:48,Hspeed:16,OSTime:8>>.

%%%
%%% 0x8601
%%% IDs : [ID0, Id1, Id2, ...]
%%%
create_del_circle_area(Count,IDs) ->
    if
        Count == 0 ->
            <<Count:8>>;
        Count =/= 0 ->
            Len = length(IDs),
            if
                Len > 125 ->
                    {IDs1, _IDs2} = lists:split(125, IDs),
                    IDsBin = list_to_binary(IDs1),
                    <<Len:8,IDsBin/binary>>;
                Len =< 125 ->
                    IDsBin = list_to_binary(IDs),
                    <<Len:8,IDsBin/binary>>
            end
    end.

%%%
%%% 0x8602
%%%
create_set_rect_area(Type,_Count,Items) ->
    Len = length(Items),
    ItemsBin = get_rect_area_entries(Items),
    <<Type:8,Len:8,ItemsBin/binary>>.
    
get_rect_area_entries(Items) ->
    case Items of
        [] ->
            <<>>;
        _ ->
            [H|T] = Items,
            {ID,Property,LeftTopLat,LeftTopLon,RightBotLat,RightBotLon,StartTime,StopTime,MaxSpeed,ExceedTime} = H,
            case T of
                [] ->
                    <<ID:32,Property:16,LeftTopLat:32,LeftTopLon:32,RightBotLat:32,RightBotLon:32,StartTime:48,StopTime:48,MaxSpeed:32,ExceedTime:8>>;
                _ ->
                    [<<ID:32,Property:16,LeftTopLat:32,LeftTopLon:32,RightBotLat:32,RightBotLon:32,StartTime:48,StopTime:48,MaxSpeed:32,ExceedTime:8>>|get_rect_area_entries(T)]
            end
    end.
    

%%%
%%%0x8603
%%% IDs : [ID0, Id1, Id2, ...]
%%%
create_del_rect_area(Count, IDs) ->
    if
        Count == 0 ->
            <<Count:8>>;
        Count =/= 0 ->
            Len = length(IDs),
            if
                Len > 125 ->
                    {IDs1, _IDs2} = lists:split(125, IDs),
                    IDsBin = list_to_binary(IDs1),
                    <<Len:8,IDsBin/binary>>;
                Len =< 125 ->
                    IDsBin = list_to_binary(IDs),
                    <<Len:8,IDsBin/binary>>
            end
    end.

%%%
%%% 0x8604
%%% Points : [[Lat0, Lon0], [Lat1, Lon1], [Lat2, Lon2], ...]
%%%
create_set_polygon_area(Id,Prop,StartTime,StopTime,MaxSpeed,OSTime,_PointsCount,Points) ->
    Len = length(Points),
    PointsBin = get_polygon_area_point_entries(Points),
    <<Id:32,Prop:16,StartTime:48,StopTime:48,MaxSpeed:16,OSTime:8,Len:16,PointsBin/binary>>.

get_polygon_area_point_entries(Items) ->
    case Items of
        [] ->
            <<>>;
        _ ->
            [H|T] = Items,
            {Lat,Lon} = H,
            case T of
                [] ->
                    <<Lat:32,Lon:32>>;
                _ ->
                    [<<Lat:32,Lon:32>>|get_polygon_area_point_entries(T)]
            end
    end.                                   
    
%%%
%%% 0x8605
%%% IDs : [ID0, Id1, Id2, ...]
%%%
create_del_polygon_area(Count, IDs) ->
    if
        Count == 0 ->
            <<Count:8>>;
        Count =/= 0 ->
            Len = length(IDs),
            if
                Len > 125 ->
                    {IDs1, _IDs2} = lists:split(125, IDs),
                    IDsBin = list_to_binary(IDs1),
                    <<Len:8,IDsBin/binary>>;
                Len =< 125 ->
                    IDsBin = list_to_binary(IDs),
                    <<Len:8,IDsBin/binary>>
            end
    end.

%%%
%%% 0x8606
%%%
create_set_lines(ID, Prop, StartTime, StopTime, _PointsCount, Points) ->
    Len = length(Points),
    PointsBin = get_lines_point_entries(Points),
    <<ID:32,Prop:16,StartTime:48,StopTime:48,Len:16,PointsBin/binary>>.

get_lines_point_entries(Items) ->
    case Items of
        [] ->
            <<>>;
        _ ->
            [H|T] = Items,
            {PointID,LineID,PointLat,PointLon,LineWidth,LineLength,LargerThr,SmallerThr,MaxSpeed,ExceedTime} = H,
            case T of
                [] ->
                    <<PointID:32,LineID:32,PointLat:32,PointLon:32,LineWidth:8,LineLength:8,LargerThr:16,SmallerThr:16,MaxSpeed:16,ExceedTime:6>>;
                _ ->
                    [<<PointID:32,LineID:32,PointLat:32,PointLon:32,LineWidth:8,LineLength:8,LargerThr:16,SmallerThr:16,MaxSpeed:16,ExceedTime:6>>|get_lines_point_entries(T)]
            end
    end.                                   
    
%%%
%%% 0x8607
%%% IDs : [ID0, Id1, Id2, ...]
%%%
create_del_lines(Count, IDs) ->
    if
        Count == 0 ->
            <<Count:8>>;
        Count =/= 0 ->
            Len = length(IDs),
            if
                Len > 125 ->
                    {IDs1, _IDs2} = lists:split(125, IDs),
                    IDsBin = list_to_binary(IDs1),
                    <<Len:8,IDsBin/binary>>;
                Len =< 125 ->
                    IDsBin = list_to_binary(IDs),
                    <<Len:8,IDsBin/binary>>
            end
    end.

%%%
%%% 0x8700
%%%
create_record_collect_cmd(OrderWord,DataBlock) ->
    DB = term_to_binary(DataBlock),
    <<OrderWord:8,DB/binary>>.

%%%
%%% 0x0700
%%%
parse_record_upload(Bin) ->
    <<Number:16,OrderWord:8,DataBlock/binary>>=Bin,
    DB = binary_to_list(DataBlock),
    {ok,{Number,OrderWord,DB}}.

%%%
%%% 0x8701
%%%
create_record_args_send(OrderWord,DataBlock) ->
    DB = list_to_binary(DataBlock),
    <<OrderWord:8,DB/binary>>.

%%%
%%% 0x0701
%%%
parse_electron_invoice_report(Bin) ->
    <<Length:32,Content/binary>> = Bin,
    {ok,{Length,Content}}.

%%%
%%% 0x8702
%%%
create_report_driver_id_request() ->
    <<>>.

%%%
%%% 0x0702
%%%
parse_driver_id_report(Bin) ->
    <<State:8,Time:48,IcReadResult:8,NameLen:8,Tail0/binary>> = Bin,
    NameBinLen = NameLen * 8,
    <<Name:NameBinLen,CerNum:20,OrgLen:8,Tail1/binary>> = Tail0,
    OrgBinLen = OrgLen * 8,
    <<Org:OrgBinLen,Validity:32>> = Tail1,
    N=binary_to_list(Name),
    O=binary_to_list(Org),
    {ok,{State,Time,IcReadResult,NameLen,N,CerNum,OrgLen,O,Validity}}.

%%%
%%% 0x0704
%%%
parse_position_data_batch_update(Bin) ->
    <<_Count:32, Type:8, Tail/binary>> = Bin,
    Positions = get_position_data_entries(Tail),
    Len = length(Positions),
    {ok, {Len,Type,Positions}}.

get_position_data_entries(Bin) ->
    Len = bit_size(Bin),
    if
        Len < 16 ->
            [];
        Len >= 16 ->
            <<Length:16, Tail0/binary>> = Bin,
            BinLength = Length * 8,
            Tail0Length = bit_size(Tail0),
            if
                BinLength > Tail0Length ->
                    [];
                BinLength =< Tail0Length ->
                    <<Msg:BinLength, Tail1/binary>> = Tail0,
                    {ok, {M}} = parse_position_info_report(Msg),
                    [[Length, M]|get_position_data_entries(Tail1)]
            end
    end.                    

%%%
%%% 0x0705
%%%
parse_CAN_data_update(Bin) ->
    <<Count:32, Time:40, Tail/binary>> = Bin,
    Data = get_CAN_data_entries(Tail),
    {ok, {Count, Time, Data}}.

get_CAN_data_entries(Bin) ->
    Len = bit_size(Bin),
    if
        Len < 96 ->
            [];
        Len >= 96 ->
            <<ID:32, Data:64, Tail/binary>> = Bin,
            TailLength = bit_size(Tail),
            if
                TailLength < 96 ->
                    [ID, Data];
                TailLength >= 96 ->
                    [[ID, Data]|get_CAN_data_entries(Tail)]
            end
    end.                    

%%%
%%% 0x0800
%%%
parse_multi_media_event_update(Bin) ->
    <<Id:32,Type:8,Code:8,EICode:8,PipeId:8>> = Bin,
    {ok,{Id,Type,Code,EICode,PipeId}}.

%%%
%%% 0x0801
%%%
parse_multi_media_data_update(Bin) ->
    <<Id:32,Type:8,Code:8,EICode:8,PipeId:8,MsgBody:(28*8),Pack/binary>> = Bin,
    {ok,{Id,Type,Code,EICode,PipeId,MsgBody,Pack}}.

%%%
%%% 0x8800
%%%
create_multimedia_data_reply(Id,_Count,IDs) ->
    Len = length(IDs),
    IL=term_to_binary(IDs),
    <<Id:32,Len:8,IL/binary>>.

%%%
%%% 0x8801
%%%
create_imm_photo_cmd(PipeId,Order,Time,SaveSymbol,DisRate,Quality,Bri,Contrast,Sat,Chroma) ->
    <<PipeId:8,Order:16,Time:16,SaveSymbol:8,DisRate:8,Quality:8,Bri:8,Contrast:8,Sat:8,Chroma:8>>.

%%%
%%% 0x0805
%%%
parse_imm_photo_cmd_response(Bin) ->
    Len = bit_size(Bin),
    if
        Len < (5*?LEN_BYTE) ->
            {error, msgerr};
        true ->
            <<RespIdx:?LEN_WORD, Res:?LEN_BYTE, Count:?LEN_WORD, Tail/binary>> = Bin,
            case Res of
                0 ->
                    List = get_list_from_bin(Tail, ?LEN_DWORD),
                    ActLen = length(List),
                    if
                        Count == ActLen ->
                            {ok, {RespIdx, Res, ActLen, List}};
                        true ->
                            {error, msgerr}
                    end;
                1 ->
                    ActLen = bit_size(Tail),
                    if
                        ActLen == 0 ->
                            {ok, {RespIdx, Res, 0, []}};
                        true ->
                            {error, msgerr}
                    end;
                2 ->
                    ActLen = bit_size(Tail),
                    if
                        ActLen == 0 ->
                            {ok, {RespIdx, Res, 0, []}};
                        true ->
                            {error, msgerr}
                    end;
                _ ->
                    {error, msgerr}
        end
    end.

get_list_from_bin(Bin, ItemWidth) ->
    Len = bit_size(Bin),
    if
        Len < ItemWidth ->
            [];
        true ->
            <<H:ItemWidth, T/binary>> = Bin,
            TLen = bit_size(T),
            if
                TLen < ItemWidth ->
                    [H];
                true ->
                    [H|get_list_from_bin(T, ItemWidth)]
            end
    end.

%%%
%%% 0x8802
%%%
create_stomuldata_search(MediaType,PipeId,EvenCode,StartTime,EndTime) ->
    <<MediaType:8,PipeId:8,EvenCode:8,StartTime:48,EndTime:48>>.

%%%
%%% 0x0802
%%%
parse_stomuldata_response(Bin) ->
    <<FlowNum:16, _Count:16, Tail/binary>> = Bin,
    Data = get_stomuldata_entries(Tail),
    Len = length(Data),
    {ok, {FlowNum, Len, Data}}.

get_stomuldata_entries(Bin) ->
    Len = bit_size(Bin),
    if
        Len < (35*8) ->
            [];
        Len >= (35*8) ->
            <<ID:32,Type:8,ChID:8,EventCoding:8,Msg:(28*8),Tail/binary>> = Bin,
            {ok, {Resp}} = parse_position_info_report(Msg),
            [[ID,Type,ChID,EventCoding,Resp]|get_stomuldata_entries(Tail)]
    end.

%%%
%%% 0x8803
%%%
create_stomuldata_update(MediaType,PipeId,EventCode,StartTime,EndTime,Del) ->
    <<MediaType:8,PipeId:8,EventCode:8,StartTime:48,EndTime:48,Del:8>>.

%%%
%%% 0x8804
%%%
create_record_start_order(RecordCode,RecordTime,SaveSymbol,VoiceSamplingRate) ->
    <<RecordCode:8,RecordTime:16,SaveSymbol:8,VoiceSamplingRate:8>>.

%%%
%%% 0x8805
%%%
create_sinstomuldatasea_update_order(MediaId,DelSymbol) ->
    <<MediaId:32,DelSymbol:8>>.

%%%
%%%0x8900
%%%
create_data_dl_transparent(MsgType,MsgCon) ->
    MC = term_to_binary(MsgCon),
    % Not complete
    <<MsgType:8,MC/binary>>.

%%%
%%%0x9000
%%%
parse_data_ul_transparent(Bin) ->
    <<Type:8,Con/binary>> = Bin,
    {ok,{Type,Con}}.

%%%
%%% 0x0901
%%%
parse_data_compress_update(Bin) ->
    <<Len:32,Body/binary>> = Bin,
    {ok,{Len,Body}}.

%%%
%%% 0x8a00
%%% Byte array to binary????
%%%
create_platform_rsa(E,N) ->
    <<E:32,N/binary>>.

%%%
%%% 0x0a00
%%%
parse_term_rsa(Bin) ->
    <<E:32,N/binary>> = Bin,
    {ok,{E,N}}.


%%%
%%% over
%%%

    
    
	    
    
    
    




    
    
    
