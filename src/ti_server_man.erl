%%%
%%% Need considering sending message to management server
%%%

-module(ti_server_man).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-record(state, {lsock}).

start_link(LSock) ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [LSock], []).

init([LSock]) ->
    {ok, #state{lsock = LSock}, 0}.

handle_call(Msg, _From, State) ->
    {reply, {ok, Msg}, State}.

handle_cast(stop, State) ->
    {stop, normal, State}.

handle_info({tcp, Socket, RawData}, State) ->
    NewState = handle_data(Socket, RawData, State),
    {noreply, NewState};
handle_info({tcp_closed, _Socket}, State) ->
    {stop, normal, State};
%%
%% we should maintain the mapping : socket, pid & VDR ID
%%
handle_info(timeout, #state{lsock = LSock} = State) ->
    {ok, SockVDR} = gen_tcp:accept(LSock),
	PidVDR = spawn(fun() -> sendback_vdr(SockVDR) end),
    ti_sup:start_child(),
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

code_change(_OldVsn, State, _Extra) ->
    {ok, State}.

%%
%% Process the data from management server.
%%     1. parse data
%%     2. send message to VDR process
%%
handle_data(Socket, RawData, State) ->
	Socket,
	RawData,
    State.

sendback_vdr(Socket) ->
	ok.
