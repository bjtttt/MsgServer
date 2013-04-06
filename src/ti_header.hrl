%%%
%%%
%%%

-define(DEF_PORT, 6000).
-define(DEF_PORT_MAN, 6001).
-define(DEF_DB, "127.0.0.1").
-define(DEF_PORT_DB, 6002).
-define(DEF_PORT_MON, 6003).

%%% DB_SUP_MAX and DB_SUP_WITHIN are use in DB Supervisor for DB client restart mechanism
%%% In development, they are 0 and 1 to make debug more easy and efficient.
%%% When release, they should be 10 and 10 OR other better values
-define(DB_SUP_MAX, 0).
-define(DB_SUP_WITHIN, 1).

%-define(LOG_DEBUG_INFO_ERR, 2).
%-define(LOG_INFO_ERR, 1).
%-define(LOG_ERR, 0).

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
                    pid=undefined, 
                    vdrpid=undefined,
                    addr=undefined, 
                    acttime=undefined, 
                    timeout=undefined,
                    msgflownum=undefined,
                    msg2vdr=[],
                    msg=[], 
                    req=[]
                 }).

%%%
%%% pid     : VDR handler process id
%%% datapid : VDR handler send data to VDR process id
%%%
-record(manitem, {socket=undefined, pid=undefined, datapid=undefined, addr=undefined, timeout=undefined}).

-record(monitem, {socket=undefined, pid=undefined, addr=undefined, timeout=undefined}).

-record(dbstate, {db=undefined, dbport=undefined, dbref=undefined, dbconnpid=undefined}).

%%%
%%% lsock       : Listening socket
%%% acceptor    : Asynchronous acceptor's internal reference
%%%
-record(serverstate, {lsock, acceptor}).

