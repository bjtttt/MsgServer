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

-module(vdr_data_processor).

-include("header.hrl").

-export([parse_msg_body/2]).

-export([create_final_msg/3,
         create_gen_resp/3, 
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
         create_send_question/3,
         create_msgmenu_settings/3,
         create_msg_service/3,
         create_tel_callback/2,
         create_tel_note/3,
         create_car_con/1,
         create_set_circle_area/11,
         create_del_circle_area/2,
         create_set_rect_area/2,
         create_del_rect_area/2,
         create_set_polygon_area/8,
         create_del_polygon_area/2,
         create_set_lines/6,
         create_del_lines/2,
         create_record_collect_cmd/2,
         create_record_args_send/2,
         create_report_driver_id_request/0,
         create_multimedia_data_reply/1,
		 create_multimedia_data_reply/2,
         create_multimedia_data_reply/3,
         create_imm_photo_cmd/10,
         create_stomuldata_search/15,
         create_stomuldata_update/16,
         create_record_start_order/4,
         create_sinstomuldatasea_update_order/2,
         create_data_dl_transparent/2,
         %create_data_ul_send/2,         
         create_platform_rsa/2,
		 get_tel_book_entries/1
	]).

-export([get_2_number_integer_from_oct_string/1]).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ID        : 
% MsgIdx    : 
% Data      : binary 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_final_msg(ID, MsgIdx, Data) ->
    %common:loginfo("vdr_data_processor:create_final_msg(ID=~p, MsgIdx=~p, Data=~p)~n", [ID, MsgIdx, Data]),
    Len = byte_size(Data),
    Header = <<ID:16, 0:2, 0:1, 0:3, Len:10, 0:48, MsgIdx:16>>,
    HeaderBody = list_to_binary([Header, Data]),
    Parity = vdr_data_parser:bxorbytelist(HeaderBody),
    MsgBody = list_to_binary([HeaderBody, Parity]),
    MsgBody1 = binary:replace(MsgBody, <<125>>, <<254, 1, 254, 2, 254, 3, 254, 4, 254, 5, 254>>, [global]),
    MsgBody2 = binary:replace(MsgBody1, <<126>>, <<255, 1, 255, 2, 255, 3, 255, 4, 255, 5, 255>>, [global]),
    MsgBody3 = binary:replace(MsgBody2, <<254, 1, 254, 2, 254, 3, 254, 4, 254, 5, 254>>, <<125, 1>>, [global]),
    MsgBody4 = binary:replace(MsgBody3, <<255, 1, 255, 2, 255, 3, 255, 4, 255, 5, 255>>, <<125, 2>>, [global]),
    list_to_binary([<<126>>, MsgBody4, <<126>>]).

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
            common:logerror("vdr_data_processor:do_parse_msg_body(ID=~p, Body) exception : ~p~n", [ID, Exception]),
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0001
% Terminal general response
%     RespIdx : WORD
%     RespID  : WORD
%     Res     : BYTE
%                 0   - SUCCESS/ACK
%                 1   - FAIL
%                 2   - MSG ERR
%                 3   - NOT SUPPORTED
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0801
% Platform general response
% Attention here : although ID is 1st parameter, it should be snd field of the message
%     RespIdx : WORD
%     RespID  : WORD
%     Resp    : BYTE
%                   0 - SUCCESS/ACK
%                   1 - FAIL
%                   2 - MSG ERR
%                   3 - NOT SUPPORTED
%                   4 - ALARM ACK
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_gen_resp(ID, FlowIdx, Resp) when is_integer(ID),
                                        is_integer(FlowIdx),
                                        is_integer(Resp),
                                        Resp >= 0,
                                        Resp =< 5 ->
    <<FlowIdx:?LEN_WORD, ID:?LEN_WORD, Resp:?LEN_BYTE>>;
create_gen_resp(_ID, _FlowIdx, _Resp) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0002
% Terminal pulse
% 
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_pulse(_Bin) ->
    {ok, {}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0803
% Platform sub-package resending request
%     OriMsgIdx   : WORD      - The index of the first sub-package of the original message
%     Count       : BYTE(n)   - The count of the whole sub-packages which are needed to be resent.
%     IDList      : BYTE(2*n) - [ID0, ID1, ID2, ID3, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_resend_subpack_req(FlowIdx, Count, IDList) when is_integer(FlowIdx),
												       is_integer(Count),
												       is_list(IDList) ->
    IsDecList = common:is_dec_list(IDList),
    if
        IsDecList == true ->
            Bin = list_to_binary([<<X:?LEN_WORD>> || X <- IDList]),
            Len = length(IDList),
            if
                Len == Count ->
                    <<FlowIdx:?LEN_WORD, Len:?LEN_BYTE, Bin/binary>>;
                true ->
                    <<>>
            end;
        true ->
            <<>>
    end;
create_resend_subpack_req(_FlowIdx, _Count, _IDList) ->
	<<>>.
	
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0100
% Terminal registration
%     Province    : WORD
%     City        : WORD
%     Producer ID : BYTE[5]
%     VDR Model   : BYTE[20]
%     VDR ID      : BYTE[7]
%     Lic Color   : BYTE
%     Lic ID      : STRING
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_reg(Bin) ->
    Len = bit_size(Bin),
    if
        Len =< ((2+2+5+20+7+1)*?LEN_BYTE) ->
            {error, msgerr};
        true ->
            <<Province:?LEN_WORD, City:?LEN_WORD, Producer:(5*?LEN_BYTE), VDRModel:(20*?LEN_BYTE), VDRID:(7*?LEN_BYTE), LicColor:?LEN_BYTE, Tail/binary>> = Bin,
            LicID = binary_to_list(Tail),
            ProducerStr = binary_to_list(<<Producer:(5*?LEN_BYTE)>>),
            VDRModelStr = binary_to_list(<<VDRModel:(20*?LEN_BYTE)>>),
            VDRIDStr = binary_to_list(<<VDRID:(7*?LEN_BYTE)>>),
            {ok, {Province, City, ProducerStr, VDRModelStr, VDRIDStr, LicColor, LicID}}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8100
%     RespIdx     : VDR message index : WORD
%     Res         : BYTE
%                     0   - OK
%                     1   - VEHICLE ALREADY REGISTERED
%                     2   - NO SUCH VEHICLE IN DATABASE
%                     3   - TERM ALREADY REGISTERED
%                     4   - NO SUCH TERM IN DATABASE
%     AuthCode    : STRING
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_reg_resp(RespIdx, Res, AuthCode) when is_integer(RespIdx),
                                             is_integer(Res),
                                             Res >= 0,
                                             Res =< 4 ->
    case AuthCode of
        empty ->
            <<RespIdx:?LEN_WORD, Res:?LEN_BYTE>>;
        _ ->
            case is_binary(AuthCode) of
                true ->
                    <<RespIdx:?LEN_WORD, Res:?LEN_BYTE, AuthCode/binary>>;
                _ ->
                    case is_list(AuthCode) of
                        true ->
                            Bin = list_to_binary(AuthCode),
                            <<RespIdx:?LEN_WORD, Res:?LEN_BYTE, Bin/binary>>;
                        _ ->
                            <<>>
                    end
            end
    end;
create_reg_resp(_RespIdx, _Res, _AuthCode) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0003
% Terminal unregistation
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_unreg(_Bin) ->
    {ok, {}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0102
%
% Return    :
%     Auth : STRING
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_check_auth(Bin) ->
    Len = bit_size(Bin),
    if
        Len < 1 ->
            {error, msgerr};
        true ->
            Auth = binary_to_list(Bin),
            {ok, {Auth}}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8103
%     Count   : BYTE
%     ArgList : [[ID0, Value0], [ID1, Value1], [ID2, Value2], ...]
%               [{ID0, Value0}, {ID1, Value1}, {ID2, Value2}, ...]
%               T-L-V : DWORD-BYTE-L*8
%
% Return    :
%       Bin | <<>>
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_set_term_args(Count, ArgList) when is_list(ArgList),
                                          Count == length(ArgList) ->
    [H|_T] = ArgList,
    if
        is_tuple(H) == true ->
            Bin = list_to_binary([compose_term_args_binary(ID, Value) || {ID, Value} <- ArgList]),
            <<Count:?LEN_BYTE,Bin/binary>>;
        is_list(H) == true ->
            Bin = list_to_binary([compose_term_args_binary(ID, Value) || [ID, Value] <- ArgList]),
            <<Count:?LEN_BYTE,Bin/binary>>;
        true ->
            <<>>
    end;
create_set_term_args(_Count, _ArgList) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% ActLen should be bit_size or byte_size ?????
% Currently using byte_size
% Has better format?
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
compose_term_args_binary(ID, Value) when is_list(ID) ->
    common:loginfo("vdr_data_processor:compose_term_args_binary(ID, Value) : (LIST)~p, ~p~n", [ID, Value]),
    case common:is_dec_integer_string(ID) of
        true ->
            IDInt = list_to_integer(ID),
            compose_term_args_binary(IDInt, Value);
        _ ->
            case common:is_hex_integer_string(ID) of
                true ->
                    IDInt = common:convert_word_hex_string_to_integer(ID),
                    compose_term_args_binary(IDInt, Value);
                _ ->
                    <<>>
            end
    end;
compose_term_args_binary(ID, Value) when is_integer(ID) ->
    common:loginfo("vdr_data_processor:compose_term_args_binary(ID, Value) : (DEC)~p, ~p~n", [ID, Value]),
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
        %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
        ID >= 16#0, ID =< 16#7 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID >= 16#8, ID =< 16#F ->                    % Impossible, the same to the other items whose length is 0.
            <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
        ID >= 16#10, ID =< 16#17 ->
            case is_binary(Value) of
                true ->
                    ActLen = byte_size(Value),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Value]);
                _ ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin])
            end;
        ID >= 16#18, ID =< 16#19 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID == 16#1A ->
            case is_binary(Value) of
                true ->
                    ActLen = byte_size(Value),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Value]);
                _ ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin])
            end;
            %Bin = list_to_binary(Value),
            %ActLen = byte_size(Bin),
            %list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
        ID >= 16#1B, ID =< 16#1C ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID == 16#1D ->
            case is_binary(Value) of
                true ->
                    ActLen = byte_size(Value),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Value]);
                _ ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin])
            end;
            %Bin = list_to_binary(Value),
            %ActLen = byte_size(Bin),
            %list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
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
            case is_binary(Value) of
                true ->
                    ActLen = byte_size(Value),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Value]);
                _ ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin])
            end;
            %Bin = list_to_binary(Value),
            %ActLen = byte_size(Bin),
            %list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
        ID >= 16#45, ID =< 16#47 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID >= 16#48, ID =< 16#49 ->
            case is_binary(Value) of
                true ->
                    ActLen = byte_size(Value),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Value]);
                _ ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin])
            end;
            %Bin = list_to_binary(Value),
            %ActLen = byte_size(Bin),
            %list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
        ID >= 16#4A, ID =< 16#4F ->                    % Impossible, the same to the other items whose length is 0.
            <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
        ID >= 16#50, ID =< 16#5A ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID >= 16#5B, ID =< 16#5E ->
            ActLen = ?LEN_WORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_WORD>>;
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
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_WORD>>;
        ID == 16#83 ->
            case is_binary(Value) of
                true ->
                    ActLen = byte_size(Value),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Value]);
                _ ->
                    Bin = list_to_binary(Value),
                    ActLen = byte_size(Bin),
                    list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin])
            end;
            %Bin = list_to_binary(Value),
            %ActLen = byte_size(Bin),
            %list_to_binary([<<ID:?LEN_DWORD>>, <<ActLen:?LEN_BYTE>>, Bin]);
        ID == 16#84 ->
            ActLen = ?LEN_BYTE_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_BYTE>>;
        ID >= 16#90, ID =< 16#92 ->
            ActLen = ?LEN_BYTE_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_BYTE>>;
        ID == 16#93 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID == 16#94 ->
            ActLen = ?LEN_BYTE_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_BYTE>>;
        ID == 16#95 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID == 16#100 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID == 16#101 ->
            ActLen = ?LEN_WORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_WORD>>;
        ID == 16#102 ->
            ActLen = ?LEN_DWORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_DWORD>>;
        ID == 16#103 ->
            ActLen = ?LEN_WORD_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_WORD>>;
        ID >= 16#110, ID =< 16#1FF ->
            ActLen = 8*?LEN_BYTE_BYTE,
            <<ID:?LEN_DWORD, ActLen:?LEN_BYTE, Value:?LEN_BYTE>>;
        ID >= 16#F000, ID =< 16#FFFF ->                    % Impossible, the same to the other items whose length is 0.
            <<ID:?LEN_DWORD, 0:?LEN_BYTE>>;
        true ->
            <<>>
    end;
compose_term_args_binary(_ID, _Value) ->
    common:logerror("vdr_data_processor:compose_term_args_binary(ID, Value) fails : ID not list or integer~n"),
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8104
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_term_query_args() ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8106
%     Count   : BYTE(n) - useless
%     IDList  : BYTE[4*n]
%                 [ID0, ID1, ID2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_query_specific_term_args(_Count, IDList) when is_list(IDList) ->
    Len = length(IDList),
    Bin = list_to_binary([<<ID:?LEN_DWORD>> || [ID] <- IDList]),
    <<Len:8,Bin/binary>>;
create_query_specific_term_args(_Count, _IDList) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0104
% Result:
%     RespIdx : WORD
%     Count   : BYTE
%     ArgList : [[ID0, Value0], [ID1, Value1], [ID2, Value2], ...]
%               T-L-V : DWORD-BYTE-L*8
%
% Len should be byte_size or bit_size????
% Currently using byte_size
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_query_term_args_response(Bin) ->
    Len = byte_size(Bin),
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Len should be byte_size or bit_size????
% Currently using byte_size
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
extract_term_args_resp(Bin) ->
    Len = byte_size(Bin),
    if
        Len < 4+1 ->
            [];
        true ->
            <<ID:?LEN_DWORD, Len:?LEN_BYTE, Tail/binary>> = Bin,
            TailLen = byte_size(Tail),
            if
                Len > TailLen ->
                    [];
                Len =< TailLen ->
                    {Bin0, Bin1} = split_binary(Tail, Len),
                    Arg = convert_term_args_binary(ID, Len, Bin0),
                    [Arg|extract_term_args_resp(Bin1)]
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8105
% Type : BYTE
% Arg  : STRING
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_term_ctrl(Type, Arg) when is_integer(Type),
                                 Type > 0,
                                 Type < 3,
                                 is_binary(Arg),
                                 byte_size(Arg) > 0 ->
    <<Type:8, Arg/binary>>;
create_term_ctrl(Type, Arg) when is_integer(Type),
                                 Type > 0,
                                 Type < 3,
                                 is_list(Arg),
                                 length(Arg) > 0 ->
    Bin = list_to_binary(Arg),
    <<Type:8, Bin/binary>>;
create_term_ctrl(Type, Arg) when is_integer(Type),
                                 Type > 0,
                                 Type < 3,
                                 is_list(Arg),
                                 length(Arg) < 1 ->
    <<Type:8>>;
create_term_ctrl(Type, Arg) when is_integer(Type),
                                 Type > 0,
                                 Type < 3,
                                 is_binary(Arg),
                                 byte_size(Arg) < 1 ->
    <<Type:8>>;
create_term_ctrl(Type, _Arg) when is_integer(Type),
                                 Type > 2,
                                 Type < 8 ->
    <<Type:8>>;
create_term_ctrl(_Type, _Arg) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8107
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_query_term_property() ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0107
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8108
% Type        : BYTE
% ProID       : BYTE[5]
% VerLen      : BYTE
% Ver         : STRING
% UpgradeLen  : DWORD
% UpgradeData :
%
% I don't know whether it is correct to process BYTE[n] by list_to_binary
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_update_packet(Type, ProID, VerLen, Ver, UpgradeLen, UpgradeData) ->
    Len0 = length(Ver),
    if
        VerLen =/= Len0 ->
            <<>>;
        true ->
            Len1 = byte_size(UpgradeData),
            if
                Len1 =/= UpgradeLen ->
                    <<>>;
                true ->
                    %ProIDBin = list_to_binary(ProID),
                    VerBin = list_to_binary(Ver),
                    %UpgradeDataBin = list_to_binary(UpgradeData),
                    Bin = list_to_binary([<<Type:?LEN_BYTE>>, ProID, <<VerLen:?LEN_BYTE>>, VerBin, <<UpgradeLen:?LEN_DWORD>>, UpgradeData]),
                    Bin
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0108
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_update_result_notification(Bin) ->
    Len = byte_size(Bin),
    if
        Len == 2 ->
            <<Type:?LEN_BYTE, Res:?LEN_BYTE>> = Bin,
            if
                Res >= 0, Res =< 2 ->
                    if
                        Type =/= 0 andalso Type =/= 12 andalso Type =/= 52 ->
                            {error, msgerr};
                        true ->
                            {ok, {Type, Res}}
                    end;
                true ->
                    {error, msgerr}
            end;
        true ->
            {error, msgerr}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0200
% Appended Information is a list, we should parse it here!!!
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_position_info_report(Bin) ->
    BinLen = byte_size(Bin),
    MinLen = 4+4+4+4+2+2+2+6,
    if
        BinLen < MinLen ->
            {error, msgerr};
        BinLen == MinLen ->
            <<AlarmSym:?LEN_DWORD, State:?LEN_DWORD, Lat:?LEN_DWORD, Lon:?LEN_DWORD, Height:?LEN_WORD, Speed:?LEN_WORD, Direction:?LEN_WORD, Time:(6*?LEN_BYTE)>> = Bin,
            H = [AlarmSym, State, Lat, Lon, Height, Speed, Direction, Time],
            {ok, {H, []}};
        true ->
            %Len = BinLen - MinLen,
            <<AlarmSym:?LEN_DWORD, State:?LEN_DWORD, Lat:?LEN_DWORD, Lon:?LEN_DWORD, Height:?LEN_WORD, Speed:?LEN_WORD, Direction:?LEN_WORD, Time:(6*?LEN_BYTE), Tail/binary>> = Bin,
            H = [AlarmSym, State, Lat, Lon, Height, Speed, Direction, Time],
            AppInfo = get_appended_info(Tail),
            case AppInfo of
                error ->
                    {error, msgerr};
                _ ->
                    {ok, {H, AppInfo}}
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_appended_info(Bin) ->
    BinLen = byte_size(Bin),
    if
        BinLen == 0 ->
            [];
        BinLen < 2 ->
            error;
        true ->
            <<ID:?LEN_BYTE, Len:?LEN_BYTE, Tail/binary>> = Bin,
            TailLen = byte_size(Tail),
            if
                Len > TailLen ->
                    error;
                Len == TailLen ->
                    [get_one_appended_info(ID, Len, Tail)];
                Len < TailLen ->
                    ValLen = Len*?LEN_BYTE,
                    <<Val:ValLen, BinTail/binary>> = Tail,
                    case get_one_appended_info(ID, Len, <<Val:ValLen>>) of
                        error ->
                            error;
                        OneAppInfo ->
                            case get_appended_info(BinTail) of
                                error ->
                                    error;
                                AppInfos ->
                                    [OneAppInfo|AppInfos]
                            end
                    end
            end
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_one_appended_info(ID, Len, Bin) ->
    ActLen = byte_size(Bin),
    case ID of
        16#1 ->
            if
                Len == 4 andalso Len == ActLen ->
                    <<Res:32>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#2 ->
            if
                Len == 2 andalso Len == ActLen ->
                    <<Res:16>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#3 ->
            if
                Len == 2 andalso Len == ActLen ->
                    <<Res:16>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#4 ->
            if
                Len == 2 andalso Len == ActLen ->
                    <<Res:16>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#11 ->
            if
                Len == 1 andalso Len == ActLen ->
                    <<Res:8>> = Bin,
                    if
                        Res == 0 ->
                            [ID, Res];
                        true ->
                            error
                    end;
                Len == 5 andalso Len == ActLen ->
                    <<Res1:8, Res2:32>> = Bin,
                    if
                        Res1 == 0 ->
                            error;
                        true ->
                            [ID, Res1, Res2]
                    end;
                true ->
                    error
            end;
        16#12 ->
            if
                Len == 6 andalso Len == ActLen ->
                    <<Res1:8, Res2:32, Res3:8>> = Bin,
                    [ID, Res1, Res2, Res3];
                true ->
                    error
            end;
        16#13 ->
            if
                Len == 7 andalso Len == ActLen ->
                    <<Res1:32, Res2:16, Res3:8>> = Bin,
                    [ID, Res1, Res2, Res3];
                true ->
                    error
            end;
        16#25 ->
            if
                Len == 4 ->
                    <<Res:32>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#2A ->
            if
                Len == 2 ->
                    <<Res:16>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#2B ->
            if
                Len == 4 ->
                    <<Res1:16, Res2:16>> = Bin,
                    [ID, Res1, Res2];
                true ->
                    error
            end;
        16#30 ->
            if
                Len == 1 ->
                    <<Res:8>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#31 ->
            if
                Len == 1 ->
                    <<Res:8>> = Bin,
                    [ID, Res];
                true ->
                    error
            end;
        16#E0 ->
            [];
        _ ->
            []
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8201
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_position_search() ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0201
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_query_position_response(Bin) ->       
    <<RespNum:16,PosMsgResp/binary>> = Bin,
    {ok, {PosMsg}} = parse_position_info_report(PosMsgResp),
    {ok, {RespNum, PosMsg}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8202
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_tmp_position_track_control(Intvl, Time) when is_integer(Intvl),
                                                    is_integer(Time) ->
    <<Intvl:16,Time:32>>;
create_tmp_position_track_control(_Intvl, _Time) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8203
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_man_confirm_alarm(Number, Type) when is_integer(Number),
                                            is_integer(Type) ->
    <<Number:16,Type:32>>;
create_man_confirm_alarm(_Number, _Type) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8300
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_txt_send(Flag, Text) when is_integer(Flag),
                                 is_binary(Text),
                                 byte_size(Text) > 0 ->
	NewText = common:convert_utf8_to_gbk(Text),
	TextBin = list_to_binary(NewText),
	<<Flag:8,TextBin/binary>>;
create_txt_send(Flag, Text) when is_integer(Flag),
                                 is_binary(Text),
                                 byte_size(Text) == 0 ->
    <<Flag:8>>;
create_txt_send(Flag, Text) when is_integer(Flag),
                                 is_list(Text),
                                 length(Text) > 0 ->
    case common:is_string(Text) of
        true ->
			NewText = common:convert_utf8_to_gbk(Text),
			TextBin = list_to_binary(NewText),
			<<Flag:8,TextBin/binary>>;
        _ ->
            <<>>
    end;
create_txt_send(Flag, Text) when is_integer(Flag),
                                 is_list(Text),
                                 length(Text) == 0 ->
    <<Flag:8>>;
create_txt_send(_Flag, _Text) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8301
% Events : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%           ConX is string with the format of binary
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_set_event(Type,_Count,Events) ->
    Len = length(Events),
    EventsBin = get_event_binary(Events, 8, 8),
    <<Type:8,Len:8,EventsBin/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Events    : [[ID0, Con0], [ID1, Con1], [ID2, Con2], ...] 
%             [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%               ConX is string with the format of binary
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_event_binary(Events, IDLen, LenLen) when is_list(Events),
                                             length(Events) > 0,
                                             is_integer(IDLen),
                                             IDLen > 0,
                                             is_integer(LenLen),
                                             LenLen > 0 ->
    [H|T] = Events,
    case length(H) of
        2 ->
            [ID,Con] = H,
            NewCon = common:convert_utf8_to_gbk(Con),
            ConBin = list_to_binary(NewCon),
            Len = byte_size(ConBin),
            case T of
                [] ->
                    <<ID:IDLen,Len:LenLen,ConBin/binary>>;
                _ ->
                    list_to_binary([<<ID:IDLen,Len:LenLen,ConBin/binary>>, get_event_binary(T, IDLen, LenLen)])
            end;
        3 ->
            [ID,_Len,Con] = H,
            NewCon = common:convert_utf8_to_gbk(Con),
            ConBin = list_to_binary(NewCon),
            Len = byte_size(ConBin),
            case T of
                [] ->
                    <<ID:IDLen,Len:LenLen,ConBin/binary>>;
                _ ->
                    list_to_binary([<<ID:IDLen,Len:LenLen,ConBin/binary>>, get_event_binary(T, IDLen, LenLen)])
            end
    end;
get_event_binary(_Events, _IDLen, _LenLen) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0301
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_event_report(Bin) ->
    Len = byte_size(Bin),
    if
        Len == 1 ->
            <<Id:8>> = <<Bin:8>>,
            {ok,{Id}};
        true ->
            {error, errmsg}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8302
% Answers : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_send_question(Flag, Ques, Answers) when is_integer(Flag),
											   is_list(Ques),
											   is_list(Answers),
											   length(Answers) > 0 ->
    NewQues = common:convert_utf8_to_gbk(Ques),
    QuesBin = list_to_binary(NewQues),
    Len = byte_size(QuesBin),
    Ans = get_event_binary(Answers, 8, 16),
    <<Flag:8,Len:8,QuesBin/binary,Ans/binary>>;
create_send_question(Flag, Ques, Answers) when is_integer(Flag),
											   is_list(Ques),
											   is_list(Answers),
											   length(Answers) == 0 -> 
    NewQues = common:convert_utf8_to_gbk(Ques),
    QuesBin = list_to_binary(NewQues),
    Len = byte_size(QuesBin),
    <<Flag:8,Len:8,QuesBin/binary>>;
create_send_question(Flag, Ques, Answers) when is_integer(Flag),
											   is_binary(Ques),
											   is_list(Answers),
											   length(Answers) > 0 -> 
    NewQues = common:convert_utf8_to_gbk(Ques),
    QuesBin = list_to_binary(NewQues),
    Len = byte_size(QuesBin),
    Ans = get_event_binary(Answers, 8, 16),
    <<Flag:8,Len:8,QuesBin/binary,Ans/binary>>;
create_send_question(Flag, Ques, Answers) when is_integer(Flag),
											   is_binary(Ques),
											   is_list(Answers),
											   length(Answers) == 0 -> 
    NewQues = common:convert_utf8_to_gbk(Ques),
    QuesBin = list_to_binary(NewQues),
    Len = byte_size(QuesBin),
    <<Flag:8,Len:8,QuesBin/binary>>;
create_send_question(_Flag, _Ques, _Answers) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0302
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_question_resp(Bin) ->
    Len = byte_size(Bin),
    if
        Len == 3 ->
            <<Number:16,Id:8>> = <<Bin:24>>,
            {ok,{Number,Id}};
        true ->
            {error, msgerr}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8303
% Msgs : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_msgmenu_settings(SetType,_Count,Msgs) ->
    Len = length(Msgs),
    MsgsBin = get_event_binary(Msgs, 8, 16),
    <<SetType:8,Len:8,MsgsBin/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0303
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_msg_proorcancel(Bin) ->
    Len = byte_size(Bin),
    if
        Len == 2 ->
            <<MsgType:8,POC:8>> = <<Bin:16>>,
            {ok,{MsgType,POC}};
        true ->
            {error, msgerr}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8304
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_msg_service(Type,Len,Con) ->
    ConBin = term_to_binary(Con),
    <<Type:8,Len:16,ConBin/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8400
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_tel_callback(Symbol, Number) when is_integer(Symbol),
                                         is_list(Number),
                                         length(Number) > 0 ->
    Len = length(Number),
    if
        Len > 20 ->
            {Num0, _Num1} = lists:split(20, Number),
            N = list_to_binary(Num0),
            <<Symbol:8,N/binary>>;
        Len =< 20 ->
            N = list_to_binary(Number),
            <<Symbol:8,N/binary>>
    end;
create_tel_callback(Symbol, Number) when is_integer(Symbol),
                                         is_binary(Number),
                                         byte_size(Number) > 0 ->
    Len = byte_size(Number),
    if
        Len > 20 ->
            Num0 = binary:part(Number, 0, 20),
            <<Symbol:8,Num0/binary>>;
        Len =< 20 ->
            <<Symbol:8,Number/binary>>
    end;
create_tel_callback(_Symbol, _Number) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8401
% Items : [[Flag,NumLen,Num,NameLen,Name], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_tel_note(Type, Count, Items) when is_integer(Type),
                                         Type >= 0,
                                         Type =< 3,
                                         is_list(Items),
                                         length(Items) > 0,
                                         is_integer(Count),
                                         Count == length(Items) ->
	ItemsBin = get_tel_book_entries(Items),
    <<Type:8,Count:8,ItemsBin/binary>>;
create_tel_note(_Type, _Count, _Items) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Items : [[Flag,NumLen,Num,NameLen,Name], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_tel_book_entries(Items) when is_list(Items),
                                 length(Items) > 0 ->
	[H|T] = Items,
    case length(H) of
        3 ->
            [Flag, Num, NameUtf8] = H,
            NumLen = byte_size(Num),
            NameGbk = common:convert_utf8_to_gbk(NameUtf8),
            Name = list_to_binary(NameGbk),
            NameLen = byte_size(Name),
			case is_integer(Flag) of
				true ->
					Bin = list_to_binary([<<Flag:8>>,<<NumLen:8>>,Num,<<NameLen:8>>,Name]),
		            case T of
		                [] ->
		                    Bin;
		                _ ->					
		                    list_to_binary([Bin, get_tel_book_entries(T)])
		            end;
				_ ->
					case is_binary(Flag) of
						true ->
							Bin = list_to_binary([Flag,<<NumLen:8>>,Num,<<NameLen:8>>,Name]),
				            case T of
				                [] ->
				                   Bin;
				                _ ->					
				                   list_to_binary([Bin, get_tel_book_entries(T)])
				            end;
						_ ->
				            case T of
				                [] ->
				                    <<>>;
				                _ ->					
				                    get_tel_book_entries(T)
				            end
					end
			end;
        5 ->
            [Flag, NumLen, Num, _NameLen, NameUtf8] = H,
			Name = code_convertor:to_gbk(NameUtf8),
            NameLen = byte_size(Name),
			case is_integer(Flag) of
				true ->
					Bin = list_to_binary([<<Flag:8>>,<<NumLen:8>>,Num,<<NameLen:8>>,Name]),
		            case T of
		                [] ->
		                    [Bin];
		                _ ->					
		                    list_to_binary([Bin, get_tel_book_entries(T)])
		            end;
				_ ->
					case is_binary(Flag) of
						true ->
							Bin = list_to_binary([Flag,<<NumLen:8>>,Num,<<NameLen:8>>,Name]),
				            case T of
				                [] ->
				                    [Bin];
				                _ ->					
				                    list_to_binary([Bin, get_tel_book_entries(T)])
				            end;
						_ ->
				            case T of
				                [] ->
				                    <<>>;
				                _ ->					
				                    list_to_binary([get_tel_book_entries(T)])
				            end
					end
			end
    end;
get_tel_book_entries(_Items) ->
    <<>>.
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8500
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_car_con(Flag) when is_integer(Flag) ->
    <<Flag:8>>;
create_car_con(_Flag) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0500
% Definition is not complete in document.
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_car_con_response(Msg) ->
    <<FlowNum:16,M/binary>> = Msg,
    {ok, Resp} = parse_position_info_report(M),
    {ok,{FlowNum, Resp}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8600
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_set_circle_area(SetArr,AreaCount,AreaId,AreaArr,Latitude,Longitude,Radius,Stime,Etime,Hspeed,OSTime) ->
    St = list_to_binary(Stime),
    Et = list_to_binary(Etime),
    <<SetArr:8,AreaCount:8,AreaId:32,AreaArr:16,Latitude:32,Longitude:32,Radius:32,St:48,Et:48,Hspeed:16,OSTime:8>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8601
% IDs : [ID0, Id1, Id2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8602
%
% Type  :
% Items : [RECT1, RECT2, ...]
%           RECT = [ID,Property,LeftTopLat,LeftTopLon,RightBotLat,RightBotLon,StartTime,StopTime,MaxSpeed,ExceedTime]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_set_rect_area(Type, Items) when is_integer(Type),
                                       is_list(Items) ->
    Len = length(Items),
    ItemsBin = get_rect_area_entries(Items),
    case ItemsBin of
        [] ->
            <<>>;
        _ ->
            list_to_binary([<<Type:8,Len:8>>, ItemsBin])
    end;
create_set_rect_area(_Type, _Items) ->
    <<>>.
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_rect_area_entries(Items) when is_list(Items) ->
    [H|T] = Items,
    Len = length(H),
    case Len of
        10 ->
            [ID,Property,LeftTopLat,LeftTopLon,RightBotLat,RightBotLon,StartTime,StopTime,MaxSpeed,ExceedTime] = H,
            StartTimeBin = convert_datetime_to_bcd(StartTime),
            StopTimeBin = convert_datetime_to_bcd(StopTime),
			LeftTopLatVal = round(convert_null_to_zero(LeftTopLat) * 1000000),
			LeftTopLonVal = round(convert_null_to_zero(LeftTopLon) * 1000000),
			RightBotLatVal = round(convert_null_to_zero(RightBotLat) * 1000000),
			RightBotLonVal = round(convert_null_to_zero(RightBotLon) * 1000000),
			MaxSpeedVal = convert_null_to_zero(MaxSpeed),
			ExceedTimeVal = convert_null_to_zero(ExceedTime),
			case ID of
				null ->
		            Bin = list_to_binary([<<-1:32,Property:16,LeftTopLatVal:32,LeftTopLonVal:32,RightBotLatVal:32,RightBotLonVal:32>>,StartTimeBin,StopTimeBin,<<MaxSpeedVal:16,ExceedTimeVal:8>>]),
		            case T of
		                [] ->
		                    [Bin];
		                _ ->
		                    [Bin|get_rect_area_entries(T)]
		            end;
				_ ->
		            Bin = list_to_binary([<<ID:32,Property:16,LeftTopLatVal:32,LeftTopLonVal:32,RightBotLatVal:32,RightBotLonVal:32>>,StartTimeBin,StopTimeBin,<<MaxSpeedVal:16,ExceedTimeVal:8>>]),
		            case T of
		                [] ->
		                    [Bin];
		                _ ->
		                    [Bin|get_rect_area_entries(T)]
		            end
			end;
        _ ->
            []
    end;
get_rect_area_entries(_Items) ->
    [].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_null_to_zero(NULL) ->
	if
		NULL == null ->
			0;
		true ->
			NULL
	end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% DateTime  : "YY-MM-DD hh:mm:ss"
%           : <<"YY-MM-DD hh:mm:ss">>
% Otherwise, "01-01-01 01:01:01" will be used
%
% Return    :
%       [1,1,1,1,1,1] and each number >= 0 and =< 99
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_datetime_to_bcd(DateTime) when is_binary(DateTime) ->
    DateTimeList = binary_to_list(DateTime),
    convert_datetime_to_bcd(DateTimeList);
convert_datetime_to_bcd(DateTime) when is_list(DateTime) ->
    case common:is_string(DateTime) of
        true ->
            DateTimeList = string:tokens(DateTime, " -:"),
            list_to_binary(convert_string_list_to_integer_list(DateTimeList));
        _ ->
            DateTimeList = string:tokens("01-01-01 01:01:01", " -:"),
            list_to_binary(convert_string_list_to_integer_list(DateTimeList))
    end;
convert_datetime_to_bcd(_DateTime) ->
    convert_datetime_to_bcd("01-01-01 01:01:01").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Convert ["NN", "NN", "NN", "NN", "NN", "NN"] to [NN, NN, NN, NN, NN, NN]
% It is for DateTime format
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
convert_string_list_to_integer_list(List) when is_list(List),
                                               length(List) == 6 ->
    [YY,MM,DD,Hh,Mm,Ss] = List,
    YYInt = get_2_number_integer_from_oct_string(YY),
    MMInt = get_2_number_integer_from_oct_string(MM),
    DDInt = get_2_number_integer_from_oct_string(DD),
    HhInt = get_2_number_integer_from_oct_string(Hh),
    MmInt = get_2_number_integer_from_oct_string(Mm),
    SsInt = get_2_number_integer_from_oct_string(Ss),
    [YYInt, MMInt, DDInt, HhInt, MmInt, SsInt];
convert_string_list_to_integer_list(_List) ->
    [1,1,1,1,1,1].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Convert "NN" to NN and MAX is 99, which means "132" will be converted to 32.
% If "NN" is not a valid decimal, return 1
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_2_number_integer_from_oct_string(Oct) when is_list(Oct),
                                               length(Oct) > 0 ->
    case common:is_dec_integer_string(Oct) of
        true ->
            Num = list_to_integer(Oct),
            Num rem 100;
        _ ->
            1
    end;
get_2_number_integer_from_oct_string(_Oct) ->
    1.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8603
% IDs : [ID0, Id1, Id2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_del_rect_area(Count, IDList) when is_list(IDList),
                                         length(IDList) == Count,
                                         Count =< 125 ->
    if
        Count == 0 ->
            <<Count:8>>;
        Count =/= 0 ->
            IDListBin = list_to_binary([<<X:?LEN_DWORD>> || X <- IDList]),
            <<Count:8,IDListBin/binary>>
    end;
create_del_rect_area(_Count, _IDs) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8604
% Points : [[Lat0, Lon0], [Lat1, Lon1], [Lat2, Lon2], ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_set_polygon_area(Id,Prop,StartTime,StopTime,MaxSpeed,OSTime,_PointsCount,Points) ->
    Len = length(Points),
    PointsBin = get_polygon_area_point_entries(Points),
    <<Id:32,Prop:16,StartTime:48,StopTime:48,MaxSpeed:16,OSTime:8,Len:16,PointsBin/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
                    list_to_binary([<<Lat:32,Lon:32>>, get_polygon_area_point_entries(T)])
            end
    end.                                   
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8605
% IDs : [ID0, Id1, Id2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8606
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_set_lines(ID, Prop, StartTime, StopTime, _PointsCount, Points) ->
    Len = length(Points),
    PointsBin = get_lines_point_entries(Points),
    <<ID:32,Prop:16,StartTime:48,StopTime:48,Len:16,PointsBin/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
                    list_to_binary([<<PointID:32,LineID:32,PointLat:32,PointLon:32,LineWidth:8,LineLength:8,LargerThr:16,SmallerThr:16,MaxSpeed:16,ExceedTime:6>>, get_lines_point_entries(T)])
            end
    end.                                   
    
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8607
% IDs : [ID0, Id1, Id2, ...]
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8700
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_record_collect_cmd(OrderWord,DataBlock) ->
    DB = term_to_binary(DataBlock),
    <<OrderWord:8,DB/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0700
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_record_upload(Bin) ->
    <<Number:16,OrderWord:8,DataBlock/binary>>=Bin,
    DB = binary_to_list(DataBlock),
    {ok,{Number,OrderWord,DB}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8701
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_record_args_send(OrderWord,DataBlock) ->
    DB = list_to_binary(DataBlock),
    <<OrderWord:8,DB/binary>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0701
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_electron_invoice_report(Bin) ->
    <<Length:32,Content/binary>> = Bin,
    {ok,{Length,Content}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8702
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_report_driver_id_request() ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0702
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_driver_id_report(Bin) ->
    <<State:8,Time:48,IcReadResult:8,NameLen:8,Tail0/binary>> = Bin,
    NameBinLen = NameLen * 8,
    <<Name:NameBinLen,CerNum:20,OrgLen:8,Tail1/binary>> = Tail0,
    OrgBinLen = OrgLen * 8,
    <<Org:OrgBinLen,Validity:32>> = Tail1,
    N=binary_to_list(Name),
    O=binary_to_list(Org),
    {ok,{State,Time,IcReadResult,NameLen,N,CerNum,OrgLen,O,Validity}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0704
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_position_data_batch_update(Bin) ->
    <<_Count:32, Type:8, Tail/binary>> = Bin,
    Positions = get_position_data_entries(Tail),
    Len = length(Positions),
    {ok, {Len,Type,Positions}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
                    [[Length, M]|[get_position_data_entries(Tail1)]]
            end
    end.                    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0705
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_CAN_data_update(Bin) ->
    <<Count:32, Time:40, Tail/binary>> = Bin,
    Data = get_CAN_data_entries(Tail),
    {ok, {Count, Time, Data}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
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
                    [[ID, Data]|[get_CAN_data_entries(Tail)]]
            end
    end.                    

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0800
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_multi_media_event_update(Bin) when is_binary(Bin),
										 byte_size(Bin) == 8 ->
    <<Id:32,Type:8,Code:8,EICode:8,PipeId:8>> = Bin,
	if
		Id > 0 andalso Type >= 0 andalso Type =< 2 andalso Code >= 0 andalso Code =< 4 andalso EICode >= 0 andalso EICode =< 7 ->
		    {ok, {Id, Type, Code, EICode, PipeId}};
		true ->
			{error, msgerr}
	end;
parse_multi_media_event_update(_Bin) ->
	{error, msgerr}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0801
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_multi_media_data_update(Bin) when is_binary(Bin),
										byte_size(Bin) >= 36 ->
    <<Id:32,Type:8,Code:8,EICode:8,PipeId:8,MsgBody:(28*8),Pack/binary>> = Bin,
	if
		Id > 0 andalso Type >= 0 andalso Type =< 2 andalso Code >= 0 andalso Code =< 4 andalso EICode >= 0 andalso EICode =< 3 ->
            case parse_position_info_report(<<MsgBody:(28*8)>>) of
                {ok, Resp} ->
		            {ok, {Id, Type, Code, EICode, PipeId, Resp, Pack}};
                _ ->
                    {error, msgerr}
            end;
		true ->
			{error, msgerr}
	end;
parse_multi_media_data_update(_Bin) ->
	{error, msgerr}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8800
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_multimedia_data_reply(Id) when is_integer(Id),
                                      Id > 0 ->
    <<Id:32>>;
create_multimedia_data_reply(_Id) ->
    <<>>.

create_multimedia_data_reply(Id, IDs) when is_integer(Id),
                                           Id > 0,
										   is_list(IDs) ->
    Len = length(IDs),
    IL = common:integer_list_to_size_binary_list(IDs, ?LEN_WORD_BYTE),
    <<Id:32,Len:8,IL/binary>>;
create_multimedia_data_reply(_Id, _IDs) ->
	<<>>.

create_multimedia_data_reply(Id, Count, IDs) when is_integer(Id),
                                                  Id > 0,
												  length(IDs) == Count ->
    Len = length(IDs),
    IL = common:integer_list_to_size_binary_list(IDs, ?LEN_WORD_BYTE),
    <<Id:32,Len:8,IL/binary>>;
create_multimedia_data_reply(_Id, _Count, _IDs) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8801
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_imm_photo_cmd(Id,Cmd,Time,SF,PPI,Quality,Bri,Contrast,Sat,Chroma) when is_integer(Id),
                                                                              Id > 0,
                                                                              is_integer(Cmd),
                                                                              Cmd >= 0,
                                                                              Cmd =< 16#FFFF,
                                                                              is_integer(Time),
                                                                              is_integer(SF),
                                                                              SF >= 0,
                                                                              SF =< 1,
                                                                              is_integer(PPI),
                                                                              PPI >= 1,
                                                                              PPI =< 8,
                                                                              is_integer(Quality),
                                                                              Quality >= 1,
                                                                              Quality =< 10,
                                                                              is_integer(Bri),
                                                                              Bri >= 0,
                                                                              Bri =< 255,
                                                                              is_integer(Contrast),
                                                                              Contrast >= 0,
                                                                              Contrast =< 127,
                                                                              is_integer(Sat),
                                                                              Sat >= 0,
                                                                              Sat =< 127,
                                                                              is_integer(Chroma),
                                                                              Chroma >= 0,
                                                                              Chroma =< 255 ->
    <<Id:8,Cmd:16,Time:16,SF:8,PPI:8,Quality:8,Bri:8,Contrast:8,Sat:8,Chroma:8>>;
create_imm_photo_cmd(_Id,_Cmd,_Time,_SF,_PPI,_Quality,_Bri,_Contrast,_Sat,_Chroma) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0805
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_imm_photo_cmd_response(Bin) ->
    Len = bit_size(Bin),
    if
        Len < (5*?LEN_BYTE) ->
            {error, msgerr};
        true ->
            <<RespIdx:?LEN_WORD, Res:?LEN_BYTE, Count:?LEN_WORD, Tail/binary>> = Bin,
            case Res of
                0 ->
                    List = get_list_from_bin(<<Tail:(Len-5*?LEN_BYTE)>>, ?LEN_DWORD),
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

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_list_from_bin(Bin, ItemWidth) when is_binary(Bin),
									   bit_size(Bin) > 0,
									   is_integer(ItemWidth),
									   ItemWidth >= 0 ->
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
                    lists:merge(H, get_list_from_bin(T, ItemWidth))
            end
    end;
get_list_from_bin(_Bin, _ItemWidth) ->
	[].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8802
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_stomuldata_search(MediaType,PipeId,EvenCode,YY0,MM0,DD0,Hh0,Mm0,Ss0,YY1,MM1,DD1,Hh1,Mm1,Ss1) when is_integer(MediaType),
																										 MediaType >= 0,
																										 MediaType =< 2,
																										 is_integer(PipeId),
																										 PipeId >= 0,
																										 is_integer(EvenCode),
																										 EvenCode >= 0,
																										 EvenCode =< 3,
																										 is_integer(YY0),
																										 YY0 >= 0,
																										 YY0 =< 99,
																										 is_integer(MM0),
																										 MM0 >= 1,
																										 MM0 =< 12,
																										 is_integer(DD0),
																										 DD0 >= 1,
																										 DD0 =< 31,
																										 is_integer(Hh0),
																										 Hh0 >= 0,
																										 Hh0 =< 23,
																										 is_integer(Mm0),
																										 Mm0 >= 0,
																										 Mm0 =< 59,
																										 is_integer(Ss0),
																										 Ss0 >= 0,
																										 Ss0 =< 59,
																										 is_integer(YY1),
																										 YY1 >= 0,
																										 YY1 =< 99,
																										 is_integer(MM1),
																										 MM1 >= 1,
																										 MM1 =< 12,
																										 is_integer(DD1),
																										 DD1 >= 1,
																										 DD1 =< 31,
																										 is_integer(Hh1),
																										 Hh1 >= 0,
																										 Hh1 =< 23,
																										 is_integer(Mm1),
																										 Mm1 >= 0,
																										 Mm1 =< 59,
																										 is_integer(Ss1),
																										 Ss1 >= 0,
																										 Ss1 =< 59 ->
	Time = list_to_binary([common:integer_to_2byte_binary(YY0),
					       common:integer_to_2byte_binary(MM0),
						   common:integer_to_2byte_binary(DD0),
						   common:integer_to_2byte_binary(Hh0),
						   common:integer_to_2byte_binary(Mm0),
						   common:integer_to_2byte_binary(Ss0),
						   common:integer_to_2byte_binary(YY1),
						   common:integer_to_2byte_binary(MM1),
						   common:integer_to_2byte_binary(DD1),
						   common:integer_to_2byte_binary(Hh1),
						   common:integer_to_2byte_binary(Mm1),
						   common:integer_to_2byte_binary(Ss1)]),							   
    list_to_binary([<<MediaType:8,PipeId:8,EvenCode:8>>, Time]);
create_stomuldata_search(_MediaType,_PipeId,_EvenCode,_YY0,_MM0,_DD0,_Hh0,_Mm0,_Ss0,_YY1,_MM1,_DD1,_Hh1,_Mm1,_Ss1) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0802
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_stomuldata_response(Bin) when is_binary(Bin),
									bit_size(Bin) >= 32 ->
    <<FlowNum:16, Count:16, Tail/binary>> = Bin,
    Data = get_stomuldata_entries(Tail),
    Len = length(Data),
	if
		len == Count ->
    		{ok, {FlowNum, Len, Data}};
		true ->
			{error, msgerr}
	end;
parse_stomuldata_response(_Bin) ->
	{error, msgerr}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
get_stomuldata_entries(Bin) when is_binary(Bin),
								 bit_size(Bin) == 35*?LEN_BYTE->
    <<ID:32,Type:8,ChID:8,EventCoding:8,Msg:(28*?LEN_BYTE),Tail/binary>> = Bin,
	case parse_position_info_report(<<Msg:(28*?LEN_BYTE)>>) of
		{ok, Resp} ->
			[[ID,Type,ChID,EventCoding,Resp]|[get_stomuldata_entries(Tail)]];
		_ ->
			[]
	end;
get_stomuldata_entries(_Bin) ->
	[].

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8803
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_stomuldata_update(MediaType,PipeId,EventCode,YY0,MM0,DD0,Hh0,Mm0,Ss0,YY1,MM1,DD1,Hh1,Mm1,Ss1,Del) when is_integer(MediaType),
																										 	  MediaType >= 0,
																										 	  MediaType =< 2,
																										 	  is_integer(PipeId),
																										 	  PipeId >= 0,
																										 	  is_integer(EventCode),
																										 	  EventCode >= 0,
																										 	  EventCode =< 3,
																										 	  is_integer(YY0),
																										 	  YY0 >= 0,
																										 	  YY0 =< 99,
																										 	  is_integer(MM0),
																										 	  MM0 >= 1,
																										 	  MM0 =< 12,
																										 	  is_integer(DD0),
																										 	  DD0 >= 1,
																										 	  DD0 =< 31,
																										 	  is_integer(Hh0),
																										 	  Hh0 >= 0,
																										 	  Hh0 =< 23,
																										 	  is_integer(Mm0),
																										 	  Mm0 >= 0,
																										 	  Mm0 =< 59,
																										 	  is_integer(Ss0),
																										 	  Ss0 >= 0,
																										 	  Ss0 =< 59,
																										 	  is_integer(YY1),
																										 	  YY1 >= 0,
																										 	  YY1 =< 99,
																										 	  is_integer(MM1),
																										 	  MM1 >= 1,
																										 	  MM1 =< 12,
																										 	  is_integer(DD1),
																										 	  DD1 >= 1,
																										 	  DD1 =< 31,
																										 	  is_integer(Hh1),
																										 	  Hh1 >= 0,
																										 	  Hh1 =< 23,
																										 	  is_integer(Mm1),
																										 	  Mm1 >= 0,
																										 	  Mm1 =< 59,
																										 	  is_integer(Ss1),
																										 	  Ss1 >= 0,
																										 	  Ss1 =< 59,
																											  is_integer(Del),
																											  Del >= 0,
																											  Del =< 1 ->
	Time = list_to_binary([common:integer_to_2byte_binary(YY0),
					       common:integer_to_2byte_binary(MM0),
						   common:integer_to_2byte_binary(DD0),
						   common:integer_to_2byte_binary(Hh0),
						   common:integer_to_2byte_binary(Mm0),
						   common:integer_to_2byte_binary(Ss0),
						   common:integer_to_2byte_binary(YY1),
						   common:integer_to_2byte_binary(MM1),
						   common:integer_to_2byte_binary(DD1),
						   common:integer_to_2byte_binary(Hh1),
						   common:integer_to_2byte_binary(Mm1),
						   common:integer_to_2byte_binary(Ss1)]),							   
    list_to_binary([<<MediaType:8,PipeId:8,EventCode:8>>,Time,<<Del:8>>]);
create_stomuldata_update(_MediaType,_PipeId,_EventCode,_YY0,_MM0,_DD0,_Hh0,_Mm0,_Ss0,_YY1,_MM1,_DD1,_Hh1,_Mm1,_Ss1,_Del) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8804
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_record_start_order(Cmd, Time, SF, Freq) when is_integer(Cmd),
                                                    Cmd >= 0,
                                                    Cmd =< 1,
                                                    is_integer(Time),
                                                    Time >= 0,
                                                    Time =< 16#FFFF,
                                                    is_integer(SF),
                                                    SF >= 0,
                                                    SF =< 1,
                                                    is_integer(Freq),
                                                    Freq >= 0,
                                                    Freq =< 3 ->
    <<Cmd:8,Time:16,SF:8,Freq:8>>;
create_record_start_order(_Cmd, _Time, _SF, _Freq) ->
    <<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8805
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_sinstomuldatasea_update_order(MediaId,DelSymbol) when is_integer(MediaId),
															 MediaId > 0,
															 is_integer(DelSymbol),
															 DelSymbol >= 0,
															 DelSymbol =< 1 ->
    <<MediaId:32,DelSymbol:8>>;
create_sinstomuldatasea_update_order(_MediaId,_DelSymbol) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
%0x8900
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_data_dl_transparent(MsgType, MsgCon) when is_integer(MsgType),
											 	 MsgType =< 255,
												 MsgType >= 0,
  												 is_list(MsgCon) ->
    Bin = <<MsgType:8>>,
	MC = list_to_binary(MsgCon),
	list_to_binary([Bin, MC]);
create_data_dl_transparent(MsgType, MsgCon) when is_integer(MsgType),
											 	 MsgType =< 255,
												 MsgType >= 0,
  												 is_binary(MsgCon) ->
    Bin = <<MsgType:8>>,
	list_to_binary([Bin, MsgCon]);
create_data_dl_transparent(_MsgType, _MsgCon) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0900
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_data_ul_transparent(Bin) when is_binary(Bin),
									bit_size(Bin) > ?LEN_BYTE ->
    <<Type:?LEN_BYTE,Con/binary>> = Bin,
    {ok,{Type,Con}};
parse_data_ul_transparent(_Bin) ->
	{error, msgerr}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0901
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_data_compress_update(Bin) when is_binary(Bin),
									 bit_size(Bin) > ?LEN_DWORD->
    <<Len:?LEN_DWORD,Body/binary>> = Bin,
    {ok,{Len,Body}}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x8a00
% Byte array to binary????
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
create_platform_rsa(E,N) when is_integer(E),
							  is_binary(N),
							  bit_size(N) == 128*?LEN_BYTE ->
    <<E:32,N/binary>>;
create_platform_rsa(_E,_N) ->
	<<>>.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% 0x0a00
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
parse_term_rsa(Bin) when is_binary(Bin),
						 bit_size(Bin) == (4+128)*?LEN_BYTE ->
    <<E:32,N/binary>> = Bin,
    {ok,{E,N}}.


%%%
%%% over
%%%

    
    
	    
    
    
    




    
    
    
