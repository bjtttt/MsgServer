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


%%%
%%% There is only one super user, name is super, password is super.
%%% 
-record(user, {id, name, level, ip, time}).

-record(vdritem, {socket, id, pid, addr, acttime, timeout}).

-record(manitem, {socket, pid, addr, timeout}).

-record(monitem, {socket, pid, addr, timeout}).

-record(dbstate, {db, dbport, dbsock}).

%%%
%%% lsock       : Listening socket
%%% acceptor    : Asynchronous acceptor's internal reference
%%%
-record(serverstate, {lsock, acceptor}).

