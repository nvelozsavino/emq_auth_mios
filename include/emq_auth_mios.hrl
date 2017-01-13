%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 03:56 PM
%%%-------------------------------------------------------------------
-author("nico").
-define(APP, emq_auth_mios).
-define(USERS_DATABASE, mios_users).
-define(DEVICES_DATABASE, mios_devices).
-define(CLIENTS_DATABASE, mios_clients).
-define(TOPICS_DATABASE, mios_topics).
-define(FUNCTION, element(2, element(2, process_info(self(), current_function)))).
-define(LV_ERROR, 1).
-define(LV_WARNING, 2).
-define(LV_STATUS, 3).
-define(LV_DEBUG, 4).

-define(DATETIME,
  lists:flatten(io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w:~3..0w",date_util:getDateTime()))).


-define(LOG_LV(Level,Format,Args),
  io:format("~2..0w ~p  ~p:~p  " ++ Format,[Level,?DATETIME,?MODULE_STRING,?FUNCTION | Args])).
-define(LOG_LV_0(Level,Format),
  io:format("~2..0w ~p  ~p:~p  " ++ Format,[Level,?DATETIME,?MODULE_STRING,?FUNCTION])).


