{application, msapp,
 [{description, "JIT Message Server"},
  {vsn, "0.1.0"},
  {modules, [msapp,
             mssup,
             vdr_server,
             mon_server,
             vdr_handler,
             mon_handler,
             common,
             vdr_data_parser,
             vdr_data_processor,
             mon_data_parser,
             mysql,
             mysql_auth,
             mysql_conn,
             mysql_msg_handler,
             mysql_recv,
             rfc4627,
             wsock_data_parser,
             wsock_client,
             wsock_framing,
             wsock_handshake,
             wsock_http,
             wsock_key,
             wsock_message]},
  {registered, [mssup]},
  {applications, [kernel, sasl, stdlib]},
  {mod, {msapp, [6000, 6001, "42.96.146.34", 9090, "42.96.146.34", "gps_database", "optimus", "opt123450", 1, 1]}}
 ]}.