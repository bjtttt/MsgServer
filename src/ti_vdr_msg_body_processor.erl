%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_msg_body_processor).

-include("ti_header.hrl").

-export([parse_msg_body/2, create_p_genans/3]).

%%%
%%% Res :
%%%     0 - SUCCESS/ACK
%%%     1 - FAIL
%%%     2 - MSG ERROR
%%%     3 - NOT SUPPORTED
%%%     4 - WARNING ACK
%%%
create_p_genans(FlowNum, ID, Res) ->
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

parse_msg_body(ID, Body) ->
    try do_parse_msg_body(ID, Body) of
        ok ->
            ok
    catch
        _:Exception ->
            ti_common:logerror("Exception when parsing message (ID:~p) body : ~p~n", [ID, Exception]),
            error
    end.

do_parse_msg_body(ID, Body) ->
    case ID of
        1 ->
            parse_t_genresp(Body);
        2 ->
            parse_t_pulse(Body);
        _ ->
            error
    end.


parse_t_genresp(Bin) ->
    <<AnsFlowNum:16, ID:16, Res:8>> = Bin, 
    {ok, {AnsFlowNum, ID, Res}}.

parse_t_pulse(Bin) ->
    {ok, {Bin}}.



