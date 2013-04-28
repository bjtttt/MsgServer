%%%
%%%
%%%

-define(MAX_VDR_ERR_COUNT, 3).

-define(DEF_PORT_DB, 3306).
-define(DEF_PORT_VDR, 6000).
-define(DEF_PORT_MON, 6001).

%%% DB_SUP_MAX and DB_SUP_WITHIN are use in DB Supervisor for DB client restart mechanism
%%% In development, they are 0 and 1 to make debug more easy and efficient.
%%% When release, they should be 10 and 10 OR other better values
-define(DB_SUP_MAX, 0).
-define(DB_SUP_WITHIN, 1).

%-define(LOG_DEBUG_INFO_ERR, 2).
%-define(LOG_INFO_ERR, 1).
%-define(LOG_ERR, 0).

-define(WAIT_LOOP_INTERVAL, 1000).

-define(TIMEOUT_VDR, 60000). 
-define(TIMEOUT_MAN, 30000). 
-define(TIMEOUT_MON, 3000). 
-define(TIMEOUT_DB, 30000). 

-define(TIMEOUT_DB_PROCESS, 1000). 
-define(DB_PROCESS_TRIAL_MAX, 10). 
-define(DB_PROCESS_FAILURE_MAX, 10). 

-define(TIMEOUT_DATA_MAN, 5). 
-define(TIMEOUT_DATA_VDR, 5). 
-define(TIMEOUT_DATA_DB, 1). 

-define(TIME_TERMINATE_VDR, 10000).
-define(TIME_TERMINATE_MAN, 5000).
-define(TIME_TERMINATE_MON, 5000).
-define(TIME_TERMINATE_DB, 5000).

-define(T_GEN_RESP_OK, 0).
-define(T_GEN_RESP_FAIL, 1).
-define(T_GEN_RESP_ERRMSG, 2).
-define(T_GEN_RESP_NOTSUPPORT, 3).

-define(P_GENRESP_OK, 0).
-define(P_GENRESP_FAIL, 1).
-define(P_GENRESP_ERRMSG, 2).
-define(P_GENRESP_NOTSUPPORT, 3).
-define(P_GENRESP_ALARMACK, 4).

-define(LEN_BYTE, 8).
-define(LEN_WORD, 16).
-define(LEN_DWORD, 32).
-define(LEN_BYTE_BYTE, 1).
-define(LEN_WORD_BYTE, 2).
-define(LEN_DWORD_BYTE, 4).

-define(CONNECTING, 0).
-define(OPEN, 1).
-define(CLOSED, 2).

%%%
%%% There is only one super user, name is super, password is super.
%%% 
-record(user, {id=undefined, name=undefined, level=undefined, ip=undefined, time=undefined}).

%%%
%%% pid     : VDR handler PID
%%% vdrpid  : VDR handler send data to VDR PID
%%%
-record(vdritem, {  socket=undefined, 
                    id=undefined,
                    auth=undefined, 
                    pid=undefined, 
                    addr=undefined, 
                    acttime=undefined, 
                    timeout=undefined,
                    msgflownum=undefined,
                    errorcount=undefined,
                    msg2vdr=[],
                    msg=[], 
                    req=[]
                 }).

-record(vdridsockitem, {    id=undefined,
                            socket=undefined,
                            addr=undefined
                       }).

%%%
%%% pid     : VDR handler process id
%%% datapid : VDR handler send data to VDR process id
%%%
-record(manitem, {  socket=undefined, 
                    pid=undefined, 
                    manpid=undefined, 
                    addr=undefined, 
                    timeout=undefined
                 }).

-record(monitem, {  socket=undefined, 
                    pid=undefined, 
                    addr=undefined, 
                    timeout=undefined
                 }).

-record(dbstate, {  db=undefined, 
                    dbport=undefined,
                    dbdsn=undefined,
                    dbname=undefined,
                    dbuid=undefined,
                    dbpwd=undefined,
                    dbconn=undefined,
                    dbref=undefined, 
                    dbpid=undefined,
                    timeout=undefined
                 }).

-record(wsstate, {  socket=undefined, 
                    state=?CONNECTING, 
                    headers=[], 
                    pid=undefined, 
                    wspid=undefined,
                    timeout=undefined,
                    wsacckey=undeifned
                 }).

%%%
%%% lsock       : Listening socket
%%% acceptor    : Asynchronous acceptor's internal reference
%%%
-record(serverstate, {lsock, acceptor}).

%% JSON - RFC 4627 - for Erlang
%%---------------------------------------------------------------------------
%% Copyright (c) 2007-2010, 2011, 2012 Tony Garnock-Jones <tonygarnockjones@gmail.com>
%% Copyright (c) 2007-2010 LShift Ltd. <query@lshift.net>
%%
%% Permission is hereby granted, free of charge, to any person
%% obtaining a copy of this software and associated documentation
%% files (the "Software"), to deal in the Software without
%% restriction, including without limitation the rights to use, copy,
%% modify, merge, publish, distribute, sublicense, and/or sell copies
%% of the Software, and to permit persons to whom the Software is
%% furnished to do so, subject to the following conditions:
%%
%% The above copyright notice and this permission notice shall be
%% included in all copies or substantial portions of the Software.
%%
%% THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
%% EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
%% MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
%% NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
%% BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
%% ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
%% CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
%% SOFTWARE.
%%---------------------------------------------------------------------------
%%
%% Convenience macros for encoding and decoding record structures.
%%
%% Erlang's compile-time-only notion of record definitions means we
%% have to supply a constant record name in the source text.

%-define(RFC4627_FROM_RECORD(RName, R),
%    ti_rfc4627:from_record(R, RName, record_info(fields, RName))).

%-define(RFC4627_TO_RECORD(RName, R),
%    ti_rfc4627:to_record(R, #RName{}, record_info(fields, RName))).
