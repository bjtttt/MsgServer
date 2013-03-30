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
         create_t_reg_resp/3]).

%%%
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
%%%
parse_msg_body(ID, Body) ->
    try do_parse_msg_body(ID, Body) of
        ok ->
            ok
    catch
        _:Exception ->
            ti_common:logerror("Exception when parsing message (ID:~p) body : ~p~n", [ID, Exception]),
            error
    end.

%%%
%%% Internal usage for parse_msg_body(ID, Body)
%%%
do_parse_msg_body(ID, Body) ->
    case ID of
        1 ->
            parse_t_genresp(Body);
        2 ->
            parse_t_pulse(Body);
        256 ->                      % 0x0100
            parse_t_reg(Body);
        3 ->
            parse_t_unreg(Body);
        258 ->                      % 0x0102
            parse_t_checkacc(Body);
        _ ->
            error
    end.

%%%
%%% Terminal general response
%%%
parse_t_genresp(Bin) ->
    <<AnsFlowNum:16, ID:16, Res:8>> = Bin, 
    {ok, {AnsFlowNum, ID, Res}}.

%%%
%%% Terminal pulse
%%% 
parse_t_pulse(Bin) ->
    {ok, {Bin}}.

%%%
%%% Platform resend sub-package request
%%% Body : [ID0, ID1, ID2, ID3, ...]
%%%
create_p_resend_subpack_req(FlowNum, ID, Body) ->
    Bin = ti_common:number_list_to_binary(Body, 16),
    <<FlowNum:16, ID:16, Bin/binary>>.

%%%
%%% Terminal registration
%%%
parse_t_reg(Bin) ->
    <<Province:16, City:16, Producer:40, Model:160, ID:56, CertColor:8, Tail/binary>> = Bin,
    CertID = binary_to_term(Tail),
    {ok, {Province, City, Producer, Model, ID, CertColor, CertID}}.

%%%
%%% AccCode : string
%%%
create_t_reg_resp(FlowNum, ID, AccCode) ->
    Bin = list_to_binary(AccCode),
    <<FlowNum:16, ID:16, Bin>>.

%%%
%%% unreg or logout?
%%%
parse_t_unreg(Bin) ->
    {ok, {Bin}}.

%%%
%%%
%%%
parse_t_checkacc(Bin) ->
    Str = binary_to_term(Bin),
    {ok, {Str}}.


