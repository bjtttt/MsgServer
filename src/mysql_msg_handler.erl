%%%
%%%
%%%

-module(mysql_msg_handler).

-include("ti_header.hrl").

-export([vdr2db_msg_handler/0]).

%%%
%%%
%%%
vdr2db_msg_handler() ->
    receive
        {_Pid, _Msg} ->
            vdr2db_msg_handler();
        stop ->
            ok
    after ?TIMEOUT_DATA_DB ->
            vdr2db_msg_handler()
    end.
