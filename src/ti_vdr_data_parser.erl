%%%
%%% This file is use to parse the data from VDR
%%% Need considering the case when > 1 packages.
%%% In this case, we need to keep the previous package.
%%%

-module(ti_vdr_data_parser).

-export([parse_data/2, compose_data/1]).

%%%
%%% Parse the data from VDR
%%%
parse_data(Socket, Data) ->
    case ti_common:safepeername(Socket) of
        {ok, {Address, _Port}} ->
            ti_common:loginfo("Data is from VDR IP : ~p~n", Address);
        {error, Explain} ->
           ti_common:loginfo("Data is from unknown VDR : ~p~n", Explain)
    end,
    VDRItem = ets:lookup(vdrtable, Socket),
    Length = length(VDRItem),
    case Length of
        1 ->
            % do concrete parse job here
            {ok, Data};
        _ ->
            ti_common:logerror("vdrtable doesn't contain the vdritem.~n"),
            error
    end.

%%%
%%% Compose the data to VDR
%%%
compose_data(Data) ->
    Data.

%%%
%%%
%%%



