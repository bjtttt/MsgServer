%%%
%%%
%%%

-module(ti_common).

-export([safepeername/1]).

safepeername(Socket) ->
	try inet:peername(Socket) of
		{ok, {Address, Port}} ->
			{ok, {inet_parse:ntoa(Address), Port}};
		{error, Reason} ->
			{error, Reason}
	catch
		_:Why ->
			{error, Why}
	end.