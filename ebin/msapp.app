{application, msapp,
 [{description, "JIT Message Server"},
  {vsn, "0.1.0"},
  {modules, [msapp,
             mssup,
             vdr_server,
             mon_server,
             mp_server,
             vdr_handler,
             mon_handler,
             mp_handler,
             code_convertor,
             iconv,
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
  {sasl, [ 
         %% minimise shell error logging 
         {sasl_error_logger, false}, 
         %% only report errors 
         {errlog_type, error}, 
         %% define the parameters of the rotating log 
         %% the log file directory 
         {error_logger_mf_dir,"./logs"}, 
         %% # bytes per logfile 
         {error_logger_mf_maxbytes,10485760}, % 10 MB 
         %% maximum number of 
         {error_logger_mf_maxfiles, 100} 
        ]},
  %{mod, {msapp, [6000, 6201, 6005, "42.96.146.34", 9090, "42.96.146.34", "gps_database", "optimus", "opt123450", 1, 1]}}
  {mod, {msapp, [6000, 6201, 6005, "42.96.146.34", 9090, "42.96.146.34", "gps_database", "optimus", "opt123450"]}}
 ]}.
