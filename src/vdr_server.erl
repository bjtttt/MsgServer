%%%
%%% Need considering how management server sends message to VDR
%%%

-module(vdr_server).

-behaviour(gen_server).

-export([start_link/1]).

-export([init/1, handle_call/3, handle_cast/2, 
         handle_info/2, terminate/2, code_change/3]). 

-include("header.hrl").

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% In fact, we can get PortVDR from msgservertable.
% Here, the reason that we use parameter is for efficiency.
%
% Result = {ok,Pid} | ignore | {error,Error}
%    Pid = pid()
%  Error = {already_started,Pid} | term()
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
start_link(PortVDR) ->  
	case gen_server:start_link({local, ?MODULE}, ?MODULE, [PortVDR], []) of
        {ok, Pid} ->
            {ok, Pid};
        ignore ->
            common:logerror("vdr_server:start_link(~p) fails : ignore~n", [PortVDR]),
            ignore;
        {already_started, Pid} ->
            common:logerror("vdr_server:start_link(~p) fails : already_started : ~p~n", [PortVDR, Pid]),
            {already_started, Pid}
    end.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% {backlog, 30} specifies the length of the OS accept queue. 
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
init([PortVDR]) ->    
	process_flag(trap_exit, true),    
	Opts = [binary, {packet, 0}, {reuseaddr, true}, {keepalive, true}, {active, once}],    
	% VDR server start listening
    case gen_tcp:listen(PortVDR, Opts) of	    
		{ok, LSock} -> 
            common:logerror("vdr_server:init([~p]) : gen_tcp:listen ok~n", [PortVDR]),
            % Create first accepting process	        
			case prim_inet:async_accept(LSock, -1) of
                {ok, Ref} ->
                    %common:loginfo("vdr_server:init([~p]) : prim_inet:async_accept accept ok~n", [PortVDR]),
                    {ok, #serverstate{lsock=LSock, acceptor=Ref}};
                Error ->
                    common:logerr("vdr_server:init([~p]) : prim_inet:async_accept accept fails : ~p~n", [PortVDR, Error]),
                    {stop, Error}
            end;
		{error, Reason} ->	        
            common:logerror("vdr_server:init([~p]) : gen_tcp:listen fails : ~p~n", [PortVDR, Reason]),
			{stop, Reason}    
	end. 

handle_call(Request, _From, State) ->    
	{stop, {unknown_call, Request}, State}.

handle_cast(_Msg, State) ->    
	{noreply, State}. 

handle_info({inet_async, LSock, Ref, {ok, CSock}}, #serverstate{lsock=LSock, acceptor=Ref}=State) ->
    %common:printsocketinfo(CSock, "Accepted one VDR"),
    try        
		case common:set_sockopt(LSock, CSock, "vdr_server:handle_info(...)") of	        
			ok -> 
				ok;	        
			{error, Reason} -> 
                common:logerror("vdr_server:handle_info(...) : common:set_sockopt(...) fails : ~p~n", [Reason]),
  				% Why use exit here?
                % {stop, set_sockpt, Reason}
                % Please consider it in the future
                exit({set_sockopt, Reason})       
		end,
		% New client connected
        % Spawn a new process using the simple_one_for_one supervisor.
        % Why it is "the simple_one_for_one supervisor"?
        case common:safepeername(CSock) of
            {ok, {Addr, _Port}} ->
                case mssup:start_child_vdr(CSock, Addr) of
                    {ok, Pid} ->
                        case gen_tcp:controlling_process(CSock, Pid) of
                            ok ->
                                ok;
                            {error, Reason1} ->
                                common:logerror("vdr_server:handle_info(...) : gen_server:controlling_process(Socket, ~p) fails : ~p~n", [Pid, Reason1]),
                                case mssup:stop_child_vdr(Pid) of
                                    ok ->
                                        ok;
                                    {error, Reason2} ->
                                        common:logerror("vdr_server:handle_info(...) : mssup:stop_child_vdr(~p) fails : ~p~n", [Pid, Reason2])
                                end
                        end;
                    {ok, Pid, _Info} ->
                        case gen_tcp:controlling_process(ç, Pid) of
                            ok ->
                                %ets:insert(vdrtable, #vdritem{socket=CSock, pid=Pid});
                                ok;
                            {error, Reason1} ->
                                common:logerror("vdr_server:handle_info(...) : gen_server:controlling_process(Socket, ~p) fails: ~p~n", [Pid, Reason1]),
                                case mssup:stop_child_vdr(Pid) of
                                    ok ->
                                        ok;
                                    {error, Reason2} ->
                                        common:logerror("vdr_server:handle_info(...) : mssup:stop_child_vdr(~p) fails : ~p~n", [Pid, Reason2])
                                end
                        end;
                    {error, already_present} ->
                        common:logerror("vdr_server:handle_info(...) : mssup:start_child_vdr fails : already_present~n");
                    {error, {already_started, Pid}} ->
                        common:logerror("vdr_server:handle_info(...) : mssup:start_child_vdr fails : already_started PID : ~p~n", [Pid]);
                    {error, Msg} ->
						terminate_invalid_vdrs(CSock),
                        common:logerror("vdr_server:handle_info(...) : mssup:start_child_vdr fails : ~p~n", [Msg])
                end;
            {error, Err} ->
                common:logerror("vdr_server:handle_info(...) : cannot start new process for new connection because common:safepeername(...) fails : ~p~n", [Err])
        end,
        %% Signal the network driver that we are ready to accept another connection        
		case prim_inet:async_accept(LSock, -1) of	        
			{ok, NewRef} -> 
                {noreply, State#serverstate{acceptor=NewRef}};
			Error ->
                common:logerror("vdr_server:handle_info(...) : prim_inet:async_accept fails : ~p~n", [inet:format_error(Error)]),
                % Why use exit here?
                % {stop, Error, State}
                % Please consider it in the future
                exit({async_accept, inet:format_error(Error)})        
		end
	catch 
		exit:Why ->        
            common:logerror("vdr_server:handle_info(...) : inet_async exception : ~p~n", [Why]),			
            {stop, Why, State}    
	end;
%%%
%%% Data should not be received here because it is a listening socket process
%%%
handle_info({tcp, Socket, Data}, State) ->  
    common:printsocketinfo(Socket, "vdr_server:handle_info(...) : data from"),
    common:logerror("(ERROR) vdr_server:handle_info(...) : data : ~p~n", [Data]),
	if
		State#serverstate.lsock =/= Socket ->
			terminate_invalid_vdrs(Socket);
		true ->
			common:logerror("(ERROR) vdr_server:handle_info(...) : cannot perform gen_tcp:close(...) ~n")
	end,
	inet:setopts(Socket, [{active, once}]),
    {noreply, State}; 
handle_info({inet_async, LSock, Ref, Error}, #serverstate{lsock=LSock, acceptor=Ref}=State) ->    
    common:logerror("(ERROR) vdr_server:handle_info(...) : inet_async error : ~p~n", [Error]),
	{stop, Error, State}; 
handle_info(_Info, State) ->    
	{noreply, State}. 

terminate(Reason, State) ->    
    common:logerror("vdr_server:terminate(...) : ~p~n", [Reason]),
	gen_tcp:close(State#serverstate.lsock),    
	ok. 

code_change(_OldVsn, State, _Extra) ->    
	{ok, State}. 
    
terminate_invalid_vdrs(Socket) ->
    SockVdrList = ets:lookup(vdrtable, Socket),
	do_terminate_invalid_vdrs(SockVdrList).

do_terminate_invalid_vdrs(States) when is_list(States),
									   length(States) > 0 ->
	[H|T] = States,
	do_terminate_invalid_vdr(H),
	do_terminate_invalid_vdrs(T);
do_terminate_invalid_vdrs(_States) ->
	ok.

do_terminate_invalid_vdr(State) ->
    %Auth = State#vdritem.auth,
    %_SerialNo = State#vdritem.serialno,
    %VehicleID = State#vdritem.vehicleid,
    Socket = State#vdritem.socket,
    VDRPid = State#vdritem.vdrpid,
	VDRMsgTimeoutPid = State#vdritem.vdrmsgtimeoutpid,
	Pid = self(),
    case VDRPid of
        undefined ->
            ok;
        _ ->
            VDRPid ! {Pid, stop},
			receive
				{Pid, stopped} ->
					ok
			after ?TIME_TERMINATE_VDR ->
					ok
			end
    end,
	case VDRMsgTimeoutPid of
		undefined ->
			ok;
		_ ->
			VDRMsgTimeoutPid ! {Pid, stop},
			receive
				{Pid, stopped} ->
					ok
			after ?TIME_TERMINATE_VDR ->
					ok
			end
	end,
    case Socket of
        undefined ->
            ok;
        _ ->
            ets:delete(vdrtable, Socket)
    end,
    %case VehicleID of
    %    undefined ->
    %        ok;
    %    _ ->
    %        {ok, WSUpdate} = wsock_data_parser:create_term_offline([VehicleID]),
    %        %common:loginfo("~p~n~p~n", [WSUpdate, list_to_binary(WSUpdate)]),
    %        vdr_handler:send_msg_to_ws(WSUpdate, State)
    %end,
    %case Auth of
    %    undefined ->
    %        ok;
    %    _ ->
    %        Sql = list_to_binary([<<"update device set is_online=0 where authen_code='">>, 
    %                              list_to_binary(Auth), 
    %                              <<"'">>]),
    %        vdr_handler:send_sql_to_db(conn, Sql, State)
    %end,
    common:loginfo("VDR Server Error : VDR (~p) : gen_tcp:close~n", [State#vdritem.addr]),
	try gen_tcp:close(State#vdritem.socket)
    catch
        _:Ex ->
            common:logerror("VDR Server Error : VDR (~p) : exception when gen_tcp:close : ~p~n", [State#vdritem.addr, Ex])
    end.
								