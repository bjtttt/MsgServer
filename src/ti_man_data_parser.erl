%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_man_data_parser).

-include("ti_header.hrl").

-export([parse_data/1]).

parse_data(Data) ->
    try do_parse_data(Data)
    catch
        _:Why ->
            ti_common:loginfo("Parsing management data exception : ~p~n", [Why]),
            {error, exception}
    end.

do_parse_data(Data) ->
    ok.