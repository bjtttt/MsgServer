%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_msg_body_processor).

-include("ti_header.hrl").

-export([parse_msg_body/2]).

-export([create_p_genresp/3, 
         create_p_resend_subpack_req/3,
         create_t_reg_resp/3,
	     create_p_set_terminal_args/2,
         create_p_query_terminal_args/0,
         create_p_query_specify_terminal_args/2,
         create_p_terminal_control/2,
         create_p_search_terminal_arr/0,
         create_p_update_packet/6,
         create_p_position_search/0,
         create_p_tmp_position_track_control/2,
         create_p_man_confirm_alarm/2,
         create_p_txt_send/2
	]).

%%%
%%% 0x0801
%%% Platform general response
%%% Res :
%%%     0 - SUCCESS/ACK
%%%     1 - FAIL
%%%     2 - MSG ERROR
%%%     3 - NOT SUPPORTED
%%%     4 - WARNING ACK
%%%
create_p_genresp(FlowNum, ID, Res) ->
    Fail = 1,
    if
        Res < 0 ->
            <<FlowNum:16, ID:16, Fail:8>>;
        Res >= 0 ->
            if
                Res > 4 ->
                    <<FlowNum:16, ID:16, Fail:8>>;
                Res =< 4 ->
                    <<FlowNum:16, ID:16, Res:8>>
            end
    end.

%%%
%%% Parse terminal message body
%%% Return :
%%%     {ok, Result}
%%%     {error, msgerr}
%%%     {error, unsupported}
%%%
parse_msg_body(ID, Body) ->
    try do_parse_msg_body(ID, Body)
    catch
        _:Exception ->
            ti_common:logerror("Exception when parsing message (ID:~p) body : ~p~n", [ID, Exception]),
            {error, msgerr}
    end.

%%%
%%% Internal usage for parse_msg_body(ID, Body)
%%%
do_parse_msg_body(ID, Body) ->
    case ID of
        1 ->                        % 0x0001
            parse_t_genresp(Body);
        2 ->                        % 0x0002
            parse_t_pulse(Body);
        256 ->                      % 0x0100
            parse_t_reg(Body);
        3 ->                        % 0x0003
            parse_t_unreg(Body);
        258 ->                      % 0x0102
            parse_t_checkacc(Body);
        260 ->                      % 0x0104
            parse_t_query_terminal_args_reponse(Body);
        263 ->                      % 0x0107
            parse_t_search_terminal_arr_response(Body);
        264 ->                      % 0x0108
            parse_t_update_result_notice(Body);
        512 ->                      % 0x0200
            parse_t_position_report(Body);
        513 ->                      % 0x0201
            parse_t_query_position_response(Body);
        _ ->
            {error, unsupported}
    end.

%%%
%%% 0x0001
%%% Terminal general response
%%%
parse_t_genresp(Bin) ->
    <<RespFlowNum:16, ID:16, Res:8>> = Bin, 
    {ok, {RespFlowNum, ID, Res}}.

%%%
%%% 0x0002
%%% Terminal pulse
%%% 
parse_t_pulse(Bin) ->
    {ok, {Bin}}.

%%%
%%% 0x0803
%%% Platform resend sub-package request
%%% Body : [ID0, ID1, ID2, ID3, ...]
%%%
create_p_resend_subpack_req(FlowNum, ID, Body) ->
    Bin = list_to_binary([<<X:16>> || X <- Body]),
    <<FlowNum:16, ID:16, Bin/binary>>.

%%%
%%% 0x0100
%%% Terminal registration
%%%
parse_t_reg(Bin) ->
    <<Province:16, City:16, Producer:40, Model:160, ID:56, CertColor:8, Tail/binary>> = Bin,
    CertID = binary_to_list(Tail),
    {ok, {Province, City, Producer, Model, ID, CertColor, CertID}}.

%%%
%%% 0x8100
%%% AccCode : string
%%%
create_t_reg_resp(FlowNum, ID, AccCode) ->
    Bin = list_to_binary(AccCode),
    <<FlowNum:16, ID:16, Bin/binary>>.

%%%
%%% 0x0003
%%% unreg or logout?
%%%
parse_t_unreg(Bin) ->
    {ok, {Bin}}.

%%%
%%% 0x0102
%%%
parse_t_checkacc(Bin) ->
    Str = binary_to_list(Bin),
    {ok, {Str}}.

%%%
%%% 0x8103
%%% Lists:[[id,value],...,[id,value]]
%%%
create_p_set_terminal_args(Count, Lists) ->
    Len = length(Lists),
    if
        Len == Count ->
            L = list_to_binary([make_to_binary(Id, Value) || [Id, Value] <- Lists]),
            <<Count:8,L/binary>>;
        Len =/= Count ->
            L = list_to_binary([make_to_binary(Id, Value) || [Id, Value] <- Lists]),
            <<Len:8,L/binary>>
     end.

make_to_binary(Id, Value) ->
    V = list_to_binary(Value),
    Len = byte_size(V),
    <<Id:32,Len:8,V:Len>>.

%%%
%%% 0x8104
%%%
create_p_query_terminal_args() ->
    <<>>.

%%%
%%% 0x8106
%%% IDs : [ID0, ID1, ID2, ...]
%%%
create_p_query_specify_terminal_args(Count, IDs) ->
    Len = length(IDs),
    if
        Len == Count ->
            IDsBin = term_to_binary(IDs),
            <<Count:8,IDsBin/binary>>;
        Len =/= Count ->
            IDsBin = term_to_binary(IDs),
            <<Len:8,IDsBin/binary>>
    end.

%%%
%%% 0x0104
%%%
parse_t_query_terminal_args_reponse(Bin) ->
    <<FlowNum:16, Count:8, Tail/binary>> = Bin,
    List = extracttermargsresp(Tail),
    Len = length(List),
    if
        Len == Count ->
            {ok, {FlowNum, Count, List}};
        Len =/= Count ->
            {ok, {FlowNum, Len, List}}
    end.

extracttermargsresp(Bin) ->
    Len = bit_size(Bin),
    if
        Len < 40 ->
            [];
        Len >= 40 ->
            <<ID:32, Len:8, Tail/binary>> = Bin,
            TailLen = bit_size(Tail),
            if
                Len > TailLen ->
                    [];
                Len =< TailLen ->
                    <<Value:Len, Body/binary>> = Tail,
                    [[ID, Len, Value]|extracttermargsresp(Body)]
            end
    end.

%%%
%%% 0x8105
%%%
create_p_terminal_control(Type, Args) ->
    case Type of
        1 ->
            List = re:split(Args, ";", [{return, list}]),
            Bin = list_to_binary(List),
            <<Type:8,Bin/binary>>;
        2 ->
            List = re:split(Args, ";", [{return, list}]),
            Bin = list_to_binary(List),
            <<Type:8,Bin/binary>>;
        _ ->
            <<Type:8>>
    end.

%%%
%%% 0x8107
%%%
create_p_search_terminal_arr() ->
    <<>>.

%%%
%%% 0x0107
%%%
parse_t_search_terminal_arr_response(Bin) ->
    <<Type:16,ProId:40,Model:160,TerId:56,ICCID:80,HaltVlen:8,HaltV:HaltVlen/binary,FwVLen:8,FwV:FwVLen/binary,GNSS:8,Arr:8>> = Bin,
    {ok,{Type,ProId,Model,TerId,ICCID,HaltVlen,HaltV,FwVLen,FwV,GNSS,Arr}}.

%%%
%%% 0x8108
%%%
create_p_update_packet(Type,ProId,Vlen,Ver,UpLen,UpPacket) ->    
    PI = list_to_binary(ProId),
    V = list_to_binary(Ver),
    UP = term_to_binary(UpPacket),
    <<Type:8,PI:40/binary,Vlen:8,V:Vlen/binary,UpLen:32,UP/binary>>.

%%%
%%% 0x0108
%%%
parse_t_update_result_notice(Bin) ->
    <<UpType:8,UpResult:8>> = Bin,
    {ok,{UpType,UpResult}}.

%%%
%%% 0x0200
%%%
parse_t_position_report(Bin) ->  
    <<AlarmSymbol:32,State:32,Latitude:32,Longitude:32,Hight:16,Speed:16,Direction:16,Time:48,Tail/binary>> = Bin,
    H = [AlarmSymbol,State,Latitude,Longitude,Hight,Speed,Direction,Time],
    Len = bit_size(Tail),
    if
	    Len > 0 ->
            <<AppId:8,AppLen:8,AppMsg/binary>> = Tail,
            {ok, {[H|[AppId,AppLen,AppMsg]]}};
        Len == 0 ->
            {ok, {H}}
    end.

%%%
%%% 0x8201
%%%
create_p_position_search() ->
    <<>>.

%%%
%%% 0x0201
%%%
parse_t_query_position_response(Bin) ->       
    <<RespNum:16,PosMsgResp/binary>> = Bin,
    {ok, {PosMsg}} = parse_t_position_report(PosMsgResp),
    {ok, {RespNum, PosMsg}}.

%%%
%%% 0x8202
%%%
create_p_tmp_position_track_control(Interval, PosTraValidity) ->
    <<Interval:16,PosTraValidity:32>>.

%%%
%%% 0x8203
%%%
create_p_man_confirm_alarm(Number,Type) ->
    <<Number:16,Type:32>>.

%%%
%%% 0x8300
%%%
create_p_txt_send(Symbol,TextMsg) ->
    TM = list_to_binary(TextMsg),
    <<Symbol:8,TM/binary>>.

%%%
%%% 0x8301
%%% Events : [[ID0, Len0, Con0], [ID1, Len1, Con1], [ID2, Len2, Con2], ...]
%%%
create_p_event_set(Type,Count,Events) ->
    C = list_to_binary(Con),
    <<Type:8,Count:8,ID:8,Len:8,Con/binary>>.

%%%
%%%0x0301
%%%
parse_t_event_report(Bin) ->
    <<Id:8>> = Bin,
    {ok,{Id}}.
%%%
%%%0x8302
%%%
create_p_question_send(Symbol,QueConLen,Que,AnsLists) ->    
    Q = list_to_binary(Que),
    Ans = term_to_binary(AnsLists),
    <<Symbol:8,QueConLen:8,Que:QueConLen/binary,Ans/binary>>.
%%%
%%%0x0302
%%%
parse_t_que_reply(Bin) ->
    <<Number:16,Id:8>> = Bin,
    {ok,{Number,Id}}.
%%%
%%%0x8303
%%%
create_p_msgmenu_set(SetType,ItemCount,MsgType,MsgNameLen,MsgName) ->
    MN = list_to_binary(MsgName),
    <<SetType:8,ItemCount:8,MsgType:8,MsgNameLen:16,MN/binary>>.
%%%
%%%0x0303
%%%
parse_t_msg_proorcancel(Bin) ->
    <<MsgType:8,POC:8>> = Bin,
    {ok,{MsgType,POC}}.
%%%
%%%0x8304
%%%
create_p_msg_service(Type,Len,Con) ->
    C = list_to_binary(Con),
    <<Type:8,Len:16,C/binary>>.
%%%
%%%0x8400
%%%
create_p_tel_answer(Symbol,Number) ->
    N = list_to_binary(Number),
    <<Symbol:8,N/binary>>.
%%%
%%%0x8401
%%%
create_p_tel_note(SetType,ConCount,ConItem) ->
    <<"">>.
%%%
%%%0x8500
%%%
create_p_car_con(Symbol) ->
    <<Symbol:8>>.
%%%
%%%0x0500
%%%
parse_t_car_con_reply(Number,MsgBody) ->
    MB = term_to_binary(MsgBody),
    <<Number:16,MB/binary>>.
%%%
%%%0x8600
%%%
create_p_set_rotundity_area(SetArr,AreaCount,AreaId,AreaArr,Latitude,Longitude,Radius,Stime,Etime,Hspeed,OSTime) ->
    St = list_to_binary(Stime),
    Et = list_to_binary(Etime),
    <<SetArr:8,AreaCount:8,AreaId:32,AreaArr:16,Latitude:32,Longitude:32,Radius:32,Stime:48/binary,Etime:48/binary,Hspeed:16,OSTime:8>>.
%%%
%%%0x8601
%%%
create_p_del_rotundity_area(Count,IDlists) ->
    IDl=term_to_binary(IDlists),
    <<Count:8,IDl/binary>>.
%%%
%%%0x8602
%%%
%create_p_set_rectangle_area

%%%
%%%0x8603
%%%
%create_p_del_rectangle_area

%%%
%%%0x8604
%%%
%create_p_set_polygon_area(Id,Arr,StartTime,EndTime,HighSpeed,OSTime,)

%%%
%%%0x8605
%%%
%create_p_del_polygon_area

%%%
%%%0x8606
%%%
%create_p_set_line()

%%%
%%%0x8607
%%%
%create_p_del_line()

%%%
%%%0x8700
%%%
create_p_record_collection_order(OrderWord,DataBlock) ->
    DB = term_to_binary(DataBlock),
    <<OrderWord:8,DB/binary>>.

%%%
%%%0x0700
%%%
parse_t_record_update(Bin) ->
    <<Number:16,OrderWord:8,DataBlock/binary>>=Bin,
    DB = binary_to_list(DataBlock),
    {ok,{Number,OrderWord,DB}}.
%%%
%%%0x8701
%%%
create_p_record_args_send(OrderWord,DataBlock) ->
    DB = list_to_binary(DataBlock),
    <<OrderWord:8,DB/binary>>.
%%%
%%%0x0701
%%%
parse_t_electron_invoice_report(Bin) ->
    <<Length:32,Content/binary>> = Bin,
    {ok,{Length,Content}}.
%%%
%%%0x8702
%%%
parse_t_report_idemsg_request(Bin) ->
    <<_/binary>> = Bin,
    {ok,{}}.
%%%
%%%0x0702
%%%
parse_t_ide_col_report(Bin) ->
    <<State:8,Time:48,IcReadResult:8,NameLen:8,Name:NameLen,CerNum:20,OrgLen:8,Org:OrgLen,Validity:32>> = Bin,
    N=binary_to_list(Name),O=binary_to_list(Org),
    {ok,{State,Time,IcReadResult,NameLen,N,CerNum,OrgLen,O,Validity}}.
%%%
%%%0704
%%%
%parse_t_site_data_update

%%%
%%%0705
%%%
%parse_t_CAN_Data_update

%%%
%%%0800
%%%
parse_t_multi_media_event_update(Bin) ->
    <<Id:32,Type:8,Code:8,EICode:8,PipeId:8>> = Bin,
    {ok,{Id,Type,Code,EICode,PipeId}}.
%%%
%%%0801
%%%
parse_t_multi_media_data_update(Bin) ->
    <<Id:32,Type:8,Code:8,EICode:8,PipeId:8,MsgBody:(28*8),Pack/binary>> = Bin,
    {ok,{Id,Type,Code,EICode,PipeId,MsgBody,Pack}}.
%%%
%%%0x8800
%%%
create_p_multimedia_data_reply(Id,PacCount,IdLists) ->
    IL=term_to_binary(IdLists),
    <<Id:32,PacCount:8,IL/binary>>.
%%%
%%%0x8801
%%%
create_p_shoot_order(PipeId,Order,Time,SaveSymbol,DisRate,Quality,Bri,Contrast,Sat,Chroma) ->
    <<PipeId:8,Order:16,Time:16,SaveSymbol:8,DisRate:8,Quality:8,Bri:8,Contrast:8,Chroma:8>>.
%%%
%%%0x0805
%%%
create_p_shoot_order_reply(ReplyNum,Result,MCount,MIdLists) ->
    MIL = term_to_binary(MIdLists),
    <<ReplyNum:16,Result:8,MCount:16,MIL/binary>>.
%%%
%%%0x8802
%%%
create_p_stomuldata_search(MediaType,PipeId,EvenCode,StartTime,EndTime) ->
    <<MediaType:8,PipeId:8,EvenCode:8,StartTime:48,EndTime:48>>.
%%%
%%%0x0802
%%%
%

%%%
%%%0x8803
%%%
create_p_stomuldata_update(MediaType,PipeId,EventCode,StartTime,EndTime,Del) ->
    <<MediaType:8,PipeId:8,EventCode:8,StartTime:48,EndTime:48,Del:8>>.
%%%
%%%0x8804
%%%
create_p_record_start_order(RecordCode,RecordTime,SaveSymbol,VoiceSamplingRate) ->
    <<RecordCode:8,RecordTime:16,SaveSymbol:8,VoiceSamplingRate:8>>.
%%%
%%%0x8805
%%%
create_p_sinstoMuldatasea_update_order(MediaId,DelSymbol) ->
    <<MediaId:32,DelSymbol:8>>.
%%%
%%%0x8900
%%%
create_p_data_send(MsgType,MsgCon) ->
    MC = term_to_binary(MsgCon),
    <<MsgType:8,MC/binary>>.
%%%
%%%0x0900
%%%
parse_t_data_update(Bin) ->
    <<MsgType:8,MsgCon/binary>> = Bin,
    MC = binary_to_term(MsgCon),
    {ok,{MsgType,MC}}.
%%%
%%%0x0901
%%%
parse_t_compress_update(Bin) ->
    <<ComLen:32,ComBody/binary>> = Bin,CB = binary_to_term(ComBody),
    {ok,{ComLen,CB}}.
%%%
%%%0x8A00
%%%
create_p_rsa(E,N) ->
    NB = term_to_binary(N),
    <<E:32,NB/binary>>.
%%%
%%%0x0A00
%%%
parse_t_rsa(Bin) ->
    <<E:32,NB/binary>> = Bin,
    N = binary_to_term(NB),
    {ok,{E,N}}.
%%%
%%%over

    
    
	    
    
    
    




    
    
    
