
-module(emq_auth_mios_SUITE).

-compile(export_all).

-include_lib("emqttd/include/emqttd.hrl").


all() -> [{group, emq_auth_mios}].

groups() -> [{emq_auth_mios,[sequence],[check_auth,check_acl]}].


init_per_suite(Config) ->
  io:format("Init per suite~n"),
  DataDir = proplists:get_value(data_dir, Config),
  application:start(lager),
  application:set_env(emqttd, conf, filename:join([DataDir, "emqttd.conf"])),
  application:ensure_all_started(emqttd),
  io:format("DataDir: ~p~n",[DataDir]),
  application:set_env(emq_auth_mios, conf, filename:join([DataDir, "emq_auth_mios.conf"])),
  application:ensure_all_started(emq_auth_mios),
  Config.

end_per_suite(_Config) ->
  application:stop(emq_auth_mios),
  application:stop(emqttd),
  emqttd_mnesia:ensure_stopped().


check_auth(_) ->
  User1 = #mqtt_client{client_id = <<"client1">>, username = <<"testuser1">>},

%%  User2 = #mqtt_client{client_id = <<"client2">>, username = <<"testuser2">>},
%%
%%  User3 = #mqtt_client{client_id = <<"client3">>},
%%
  ok = emqttd_access_control:auth(User1, <<"pass1">>),
%%  {error, _} = emqttd_access_control:auth(User1, <<"pass">>),
%%  {error, password_undefined} = emqttd_access_control:auth(User1, <<>>),
%%
%%  ok = emqttd_access_control:auth(User2, <<"pass2">>),
%%  ok = emqttd_access_control:auth(User2, <<>>),
%%  ok = emqttd_access_control:auth(User2, <<"errorpwd">>),
%%
%%
%%  {error, _} = emqttd_access_control:auth(User3, <<"pwd">>).
  ok.

check_acl()->
  ok.