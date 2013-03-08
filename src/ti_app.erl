-module(ti_app).

-behaviour(application).

-include("ti_common.hrl").

-export([start/1, start/2, stop/1]).


start(_StartType, StartArgs) ->
    % Initialize tables
    % This table should include:
    % DB PID : it is used for the communication with VDR
    ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
    % It seems to be a little stupid to use two tables.
    % However, I haven't found a more efficient way to look up VDR ID from VDR Socket or reversely.
    % PID is used for the communication with DB & Manange Platform
    % Key - Value, PID : VDR Socket : VDR ID, PID
    ets:new(vdrinittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
    % Key - Value, PID : VDR ID : VDR Socket, PID
    ets:new(vdrtable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
    % There will be more than one management platforms.
    % However, I still don't know how to deal with them.
    % This table is use to store the information for Socket(?), PID, and others(?)
    % PID is used for the commnunication with VDR
    ets:new(mantable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
    case ti_sup:start_link(StartArgs) of
        {ok, Pid} ->
            {ok, Pid};
        Other ->
            {error, Other}
    end.

stop(_State) ->
    %error_logger:info_msg("Msg server stops.~n"),
    ok.

%%%
%%% Useless function
%%%
%%%
%%% Steps :
%%%     1. Start connection to DB
%%%     2. Start server for management
%%%     3. Start server for VDR
%%%     4. Start server for monitor
%%%
%%%  msgservertable : common states
%%%  vdrinittable, vdrtable : when VDR connects, keep its socket as key in vdrinittable first.
%%%                           after receiving VDR ID, the entry will be moved to vdrtable and use VDR ID as key instead.
%%%  mantable : 
%%%
start(StartArgs) ->
    PidApp = self(),
	% shall we call add_handler?
	%ti_event_api:start_link(),
	try
		[DefPort, DefPortMan, DefDB, DefPortDB, DefPortMon] = StartArgs,
		ets:new(msgservertable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(vdrinittable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(vdrtable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		ets:new(mantable,[set,public,named_table,{keypos,1},{read_concurrency,true},{write_concurrency,true}]),
		error_logger:info_msg("Server tables are ok.~n"),
		% make sure that msgserver can get stop message from any internal process?
	    ets:insert(msgservertable, {apppid,PidApp}),
		error_logger:info_msg("Server application PID : ~p~n",[PidApp]),
		% start DB client
		case gen_tcp:listen(DefPortDB, [{active,true}]) of
			{ok, LSock} ->
				error_logger:info_msg("Database starts listening.~n"),
				case ti_sup_db:start_link(LSock, DefDB, DefPortDB) of
			        {ok, Pid} ->
						error_logger:info_msg("Database supervisor starts.~n"),
			            ets:insert(msgservertable, {supdbpid, Pid}),
			            ets:insert(msgservertable, {supdblsock, LSock}),
			            ti_sup_db:start_child(),
						% start management server, VDR server & monitor server
						case start_server_man(DefPortMan, DefPort, DefPortMon) of
							ok ->
								error_logger:info_msg("Msg server starts.~n"),
								{ok, Pid};
							ignore ->
								{error, ignore};
							{error, Error} ->
								{error, Error}
						end;
					ignore ->
                        error_logger:error_msg("Cannot start connetion to DB : ignore~nExit.~n"),
			            {error, ignore};
			        {error, Error} ->
						case Error of
							{already_started, Pid} ->
			            		error_logger:error_msg("Cannot start connetion to DB : already started - ~p~nExit.~n", [Pid]),
                                {error, {already_started, Pid}};
							{shutdown, Term} ->
			            		error_logger:error_msg("Cannot start connetion to DB : shutdown - ~p~nExit.~n", [Term]),
                                {error, {shutdown, Term}};
							Term ->
								error_logger:error_msg("Cannot start connetion to DB : ~p~nExit.~n", [Term]),
                                {error, Term}
						end
			    end;
			{error, Reason} ->
				error_logger:error_msg("Cannot start connetion to DB : ~p~nExit.~n", [Reason]),
                {error, Reason}
		end
	catch
		error:AppError ->
			error_logger:error_msg("Server application fails (error) : ~p~nExit.~n", [AppError]),
            {error, AppError};
		throw:AppThrow ->
			error_logger:error_msg("Server application fails (throw) : ~p~nExit.~n", [AppThrow]),
            {error, AppThrow};
		exit:AppReason ->
			error_logger:error_msg("Server application fails (exit) : ~p~nExit.~n", [AppReason]),
            {error, AppReason}
	end.			

%%%
%%% Useless function
%%%
%%%
%%% Start management server
%%% VDR server and monitor server will also be started here
%%%
start_server_man(PortMan, Port, PortMon) ->
	case gen_tcp:listen(PortMan, [{active, true}]) of
		{ok, LSock} ->
			error_logger:info_msg("Management starts listening.~n"),
		    case ti_sup_man:start_link(LSock) of
		        {ok,Pid} ->
					error_logger:info_msg("Management supervisor starts.~n"),
    				ets:insert(msgservertable,{supmanpid,Pid}),
    				ets:insert(msgservertable,{supmanlsock,LSock}),
		            ti_sup_man:start_child(),
					% start VDR server & monitor server
					start_server(Port, PortMon);
				ignore ->
		            error_logger:error_msg("Cannot start server for management : ignore~nExit.~n"),
                    ignore;
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		error_logger:error_msg("Cannot start server for management : already started - ~p~nExit.~n", [Pid]),
                            {error, shutdown};
						{shutdown, Term} ->
		            		error_logger:error_msg("Cannot start server for management : shutdown - ~p~nExit.~n", [Term]),
                            {error, shutdown};
						Term ->
							error_logger:error_msg("Cannot start server for management : ~p~nExit.~n", [Term]),
                            {error, shutdown}
					end
		    end;
		{error, Reason} ->
			error_logger:error_msg("Cannot start server for management : ~p~nExit.~n", [Reason]),
            {error, shutdown}
	end.

%%%
%%% Useless function
%%%
%%%
%%% Start VDR server
%%% Monitor server will also be started here
%%%
start_server(Port, PortMon) ->
	case gen_tcp:listen(Port, [{active, true}]) of
		{ok, LSock} ->
			error_logger:info_msg("VDR starts listening.~n"),
		    case ti_sup:start_link(LSock) of
		        {ok, Pid} ->
					error_logger:info_msg("VDR supervisor starts.~n"),
					ets:insert(msgservertable,{suppid,Pid}),
					ets:insert(msgservertable,{suplsock,LSock}),
		            ti_sup:start_child(),
					% start monitor server
					start_server_mon(PortMon);
				ignore ->
		            error_logger:error_msg("Cannot start server for VDR : ignore~nExit.~n"),
                    ignore;
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		error_logger:error_msg("Cannot start server for VDR : already started - ~p~nExit.~n", [Pid]),
                            {error, {already_started, Pid}};
						{shutdown, Term} ->
		            		error_logger:error_msg("Cannot start server for VDR : shutdown - ~p~nExit.~n", [Term]),
                            {error, {shutdown, Term}};
						Term ->
							error_logger:error_msg("Cannot start server for VDR : ~p~nExit.~n", [Term]),
                            {error, Term}
					end
		    end;
		{error, Reason} ->
			error_logger:error_msg("Cannot start server for VDR : ~p~nExit.~n", [Reason]),
            {error, Reason}
	end.

%%%
%%% Useless function
%%%
%%%
%%% Start monitor server
%%%
start_server_mon(Port) ->
	case gen_tcp:listen(Port, [{active, true}]) of
		{ok, LSock} ->
			error_logger:info_msg("Monitor starts listening.~n"),
		    case ti_sup_mon:start_link(LSock) of
		        {ok, Pid} ->
					error_logger:info_msg("Monitor supervisor starts.~n"),
					ets:insert(msgservertable,{supmonpid,Pid}),
					ets:insert(msgservertable,{supmonlsock,LSock}),
		            ti_sup_mon:start_child(),
				    ok;
				ignore ->
		            error_logger:error_msg("Cannot start server for monitor : ignore~nExit.~n"),
                    ignore;
		        {error, Error} ->
					case Error of
						{already_started, Pid} ->
		            		error_logger:error_msg("Cannot start server for monitor : already started - ~p~nExit.~n", [Pid]),
                            {error, {already_started, Pid}};
						{shutdown, Term} ->
		            		error_logger:error_msg("Cannot start server for monitor : shutdown - ~p~nExit.~n", [Term]),
                            {error, {shutdown, Term}};
						Term ->
							error_logger:error_msg("Cannot start server for monitor : ~p~nExit.~n", [Term]),
                            {error, Term}
					end
		    end;
		{error, Reason} ->
			error_logger:error_msg("Cannot start server for monitor : ~p~nExit.~n", [Reason]),
            {error, Reason}
	end.

%%%
%%% Application get stop message.
%%% Need keeping some states?
%%% Is this function proper?
%%%
%app_message_processor() ->
%	receive
%			exit("~p~nMsgServer stops.~n", [Msg]);
%		_ ->
%			app_message_processor()
%	end.
