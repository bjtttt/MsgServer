%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_data_parser).

-export([parse_data/1, compose_data/1]).

%%%
%%% Parse the data from VDR
%%%
parse_data(Data) ->
    Data.

%%%
%%% Compose the data to VDR
%%%
compose_data(Data) ->
    Data.



