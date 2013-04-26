%%%
%%% This file is use to parse the data from monitor
%%%

-module(mon_data_parser).

-export([parse_data/1]).

parse_data(RawData) ->
    RawData.