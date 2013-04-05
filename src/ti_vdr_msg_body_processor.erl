%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_msg_body_processor).

-include("ti_header.hrl").

-export([parse_msg_body/2]).

-export([create_general_response/3, 
         create_resend_subpack_req/3,
         create_reg_resp/3,
	     create_set_terminal_args/2,
         create_query_terminal_args/0,
         create_query_specify_terminal_args/2,
         create_terminal_control/2,
         create_search_terminal_arr/0,
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
         create_shoot_order/10,
         create_shoot_order_response/4,
         create_stomuldata_search/5,
         create_stomuldata_update/6,
         create_record_start_order/4,
         create_sinstomuldatasea_update_order/2,
         create_data_send/2,
         create_rsa/2
	]).

%%%
%%% 0x0801
%%% Platform general response
%%% Res :
%%%     0 - SUCCESS/ACK
%%%     1 - FAIL
%%%     2 - MSG ERROR
%%%     3 - NOT SUPPORTED
%%%     4 - ALARM ACK
%%%
create_general_response(FlowIdx, ID, Resp) ->
    if
        Resp < 0 ->
            <<FlowIdx:16, ID:16, ?P_GENRESP_FAIL:8>>;
        Resp >= 0 ->
            if
                Resp > 4 ->
                    <<FlowIdx:16, ID:16, ?P_GENRESP_FAIL:8>>;
                Resp =< 4 ->
                    <<FlowIdx:16, ID:16, Resp:8>>
            end
    end.

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
        1 ->                        % 0x0001
            parse_genresp(Body);
        2 ->                        % 0x0002
            parse_pulse(Body);
        256 ->                      % 0x0100
            parse_reg(Body);
        3 ->                        % 0x0003
            parse_unreg(Body);
        258 ->                      % 0x0102
            parse_checkacc(Body);
        260 ->                      % 0x0104
            parse_query_terminal_args_reponse(Body);
        263 ->                      % 0x0107
            parse_search_terminal_arr_response(Body);
        264 ->                      % 0x0108
            parse_update_result_notice(Body);
        512 ->                      % 0x0200
            parse_position_report(Body);
        513 ->                      % 0x0201
            parse_query_position_response(Body);
        769 ->                      % 0x0301
            parse_event_report(Body);
        770 ->                      % 0x0302
            parse_question_resp(Body);
        771 ->                      % 0x0303
            parse_msg_proorcancel(Body);
        1280 ->                     % 0x0500
            parse_car_con_response(Body);
        1792 ->                     % 0x0700
            parse_record_upload(Body);
        1793 ->                     % 0x0701
            parse_electron_invoice_report(Body);
        1794 ->                     % 0x0702
            parse_driver_id_report(Body);
        1796 ->                     % 0x0704
            parse_position_data_batch_update(Body);
        1797 ->                     % 0x0705
            parse_CAN_data_update(Body);
        2048 ->                     % 0x0800
            parse_multi_media_event_update(Body);
        2049 ->                     % 0x0809
            parse_multi_media_data_update(Body);
        2050 ->                     % 0x0802
            parse_stomuldata_response(Body);
        2304 ->                     % 0x0900
            parse_data_update(Body);
        2305 ->                     % 0x0901
            parse_compress_update(Body);
        2560 ->                     % 0x0a00
            parse_rsa(Body);
        _ ->
            {error, unsupported}
    end.

%%%
%%% 0x0001
%%% Terminal general response
%%%
parse_genresp(Bin) ->
    <<RespFlowNum:16, ID:16, Res:8>> = Bin, 
    {ok, {RespFlowNum, ID, Res}}.

%%%
%%% 0x0002
%%% Terminal pulse
%%% 
parse_pulse(Bin) ->
    {ok, {Bin}}.

%%%
%%% 0x0803
%%% Platform resend sub-package request
%%% Body : [ID0, ID1, ID2, ID3, ...]
%%%
create_resend_subpack_req(FlowNum, ID, Body) ->
    Bin = list_to_binary([<<X:16>> || X <- Body]),
    <<FlowNum:16, ID:16, Bin/binary>>.

%%%
%%% 0x0100
%%% Terminal registration
%%%
parse_reg(Bin) ->
    <<Province:16, City:16, Producer:40, Model:160, ID:56, CertColor:8, Tail/binary>> = Bin,
    CertID = binary_to_list(Tail),
    {ok, {Province, City, Producer, Model, ID, CertColor, CertID}}.

%%%
%%% 0x8100
%%% AccCode : string
%%%
create_reg_resp(FlowNum, ID, AccCode) ->
    Bin = list_to_binary(AccCode),
    <<FlowNum:16, ID:16, Bin/binary>>.

%%%
%%% 0x0003
%%% unreg or logout?
%%%
parse_unreg(Bin) ->
    {ok, {Bin}}.

%%%
%%% 0x0102
%%%
parse_checkacc(Bin) ->
    Str = binary_to_list(Bin),
    {ok, {Str}}.

%%%
%%% 0x8103
%%% Lists:[[id,value],...,[id,value]]
%%%
create_set_terminal_args(_Count, Lists) ->
    Len = length(Lists),
    L = list_to_binary([make_to_binary(Id, Value) || [Id, Value] <- Lists]),
    <<Len:8,L/binary>>.

make_to_binary(Id, Value) ->
    V = list_to_binary(Value),
    Len = byte_size(V),
    <<Id:32,Len:8,V/binary>>.

%%%
%%% 0x8104
%%%
create_query_terminal_args() ->
    <<>>.

%%%
%%% 0x8106
%%% IDs : [ID0, ID1, ID2, ...]
%%%
create_query_specify_terminal_args(_Count, IDs) ->
    Len = length(IDs),
    IDsBin = term_to_binary(IDs),
    <<Len:8,IDsBin/binary>>.

%%%
%%% 0x0104
%%%
parse_query_terminal_args_reponse(Bin) ->
    <<FlowNum:16, _Count:8, Tail/binary>> = Bin,
    List = extracttermargsresp(Tail),
    Len = length(List),
    {ok, {FlowNum, Len, List}}.

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
create_terminal_control(Type, Args) ->
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
create_search_terminal_arr() ->
    <<>>.

%%%
%%% 0x0107
%%%
parse_search_terminal_arr_response(Bin) ->
    <<Type:16,ProId:40,Model:160,TerId:56,ICCID:80,HaltVLen:8,Tail0/binary>> = Bin,
    HaltVBinLen = HaltVLen * 8,
    <<HaltV:HaltVBinLen,FwVLen:8,Tail1/binary>> = Tail0,
    FwVBinLen = FwVLen * 8,
    <<FwV:FwVBinLen,GNSS:8,Arr:8>> = Tail1,
    {ok,{Type,ProId,Model,TerId,ICCID,HaltVLen,HaltV,FwVLen,FwV,GNSS,Arr}}.

%%%
%%% 0x8108
%%%
create_update_packet(Type,ProId,Vlen,Ver,UpLen,UpPacket) ->    
    PI = list_to_binary(ProId),
    V = list_to_binary(Ver),
    UP = term_to_binary(UpPacket),
    <<Type:8,PI:40/binary,Vlen:8,V:Vlen/binary,UpLen:32,UP/binary>>.

%%%
%%% 0x0108
%%%
parse_update_result_notice(Bin) ->
    <<UpType:8,UpResult:8>> = Bin,
    {ok,{UpType,UpResult}}.

%%%
%%% 0x0200
%%%
parse_position_report(Bin) ->  
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
create_position_search() ->
    <<>>.

%%%
%%% 0x0201
%%%
parse_query_position_response(Bin) ->       
    <<RespNum:16,PosMsgResp/binary>> = Bin,
    {ok, {PosMsg}} = parse_position_report(PosMsgResp),
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
    {ok, Resp} = parse_position_report(M),
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
                    {ok, {M}} = parse_position_report(Msg),
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
create_shoot_order(PipeId,Order,Time,SaveSymbol,DisRate,Quality,Bri,Contrast,Sat,Chroma) ->
    <<PipeId:8,Order:16,Time:16,SaveSymbol:8,DisRate:8,Quality:8,Bri:8,Contrast:8,Sat:8,Chroma:8>>.

%%%
%%% 0x0805
%%%
create_shoot_order_response(ReplyNum,Result,_MCount,MIDs) ->
    Len = length(MIDs),
    Bin = list_to_binary([<<X:32>> || X <- MIDs]),
    <<ReplyNum:16,Result:8,Len:16,Bin/binary>>.

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
            {ok, {Resp}} = parse_position_report(Msg),
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
create_data_send(MsgType,MsgCon) ->
    MC = term_to_binary(MsgCon),
    <<MsgType:8,MC/binary>>.

%%%
%%% 0x0900
%%%
parse_data_update(Bin) ->
    <<Type:8,Con/binary>> = Bin,
    {ok,{Type,Con}}.

%%%
%%% 0x0901
%%%
parse_compress_update(Bin) ->
    <<Len:32,Body/binary>> = Bin,
    {ok,{Len,Body}}.

%%%
%%% 0x8a00
%%% Byte array to binary????
%%%
create_rsa(E,N) ->
    <<E:32,N/binary>>.

%%%
%%% 0x0a00
%%%
parse_rsa(Bin) ->
    <<E:32,N/binary>> = Bin,
    {ok,{E,N}}.


%%%
%%% over
%%%

    
    
	    
    
    
    




    
    
    
