%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_man_data_parser).

-include("ti_header.hrl").

-export([process_data/2]).

process_data(State, Data) ->
    try do_process_data(Data)
    catch
        _:Why ->
            ti_common:loginfo("Parsing management data exception : ~p~n", [Why]),
            {error, exception, State}
    end.

do_process_data(Data) ->
    {ok, Erl, Rest} = ti_rfc4627:decode(Data).