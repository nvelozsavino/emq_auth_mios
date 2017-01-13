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
-define(LV_ERROR, "01").
-define(LV_WARNING, "02").
-define(LV_STATUS, "03").
-define(LV_DEBUG, "04").

-define(LOG_LV(Level,Format,Args),
  io:format("~p\t~p\t~p:~p\t" ++ Format,[Level,date_util:getDateTime(),?MODULE_STRING,?FUNCTION | Args])).
-define(LOG_LV_0(Level,Format),
  io:format("~p\t~p\t~p:~p\t" ++ Format,[Level,date_util:getDateTime(),?MODULE_STRING,?FUNCTION])).


