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

-define(TIMEOUT_DATA_MAN, 5). 
-define(TIMEOUT_DATA_VDR, 5). 
-define(TIMEOUT_DATA_DB, 1). 


%%%
%%% There is only one super user, name is super, password is super.
%%% 
-record(user, {id=undefined, name=undefined, level=undefined, ip=undefined, time=undefined}).

%%%
%%% pid     : management handler process id
%%% datapid : management handler send data to management process id
%%%
-record(vdritem, {socket=undefined, id=undefined, pid=undefined, datapid=undefined, addr=undefined, acttime=undefined, timeout=undefined}).

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

