%%%
%%% This file is use to parse the data from management
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_man_data_parser).

-export([parse_data/1]).

parse_data(RawData) ->
    RawData.