%%%
%%% This file is use to parse the data from monitor
%%%

-module(ti_mon_data_parser).

-export([parse_data/1]).

parse_data(RawData) ->
    RawData.