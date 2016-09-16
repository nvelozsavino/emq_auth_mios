%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:28 AM
%%%-------------------------------------------------------------------

%% @doc emqttd mios plugin application.
-module(emqttd_mios_plugin_app).

-behaviour(application).

-define(APP, emqttd_auth_ldap).

%% Application callbacks
-export([start/2, stop/1]).

get_public_key(Env)->
%%  PublicKeyFile = "/home/nico/Downloads/Skype/pubkey.pem",
%%  PublicKeyFile.
  PublicKeyFile = get_value(pubkey, Env, "default_pubkey.pem"),
  io:format("PublicKeyFile: ~p~n",[PublicKeyFile]),
  Verify= gen_conf:value(emqttd_mios_plugin, verify),
  if
    Verify==false ->
      no_verify;
    true->
      PublicKeyFile = emqttd_mios_plugin_utils:load_key(PublicKeyFile),
      PublicKeyFile
  end.

start(_StartType, _StartArgs) ->
  gen_conf:init(?APP),
  {ok, Sup} = emqttd_mios_plugin_sup:start_link(),
  Env = gen_conf:value(?APP, mios),
  io:format("Env: ~p~n",Env),
  PubKeyFile=get_public_key(Env),
  emqttd_mios_plugin:load([]),
  ok = emqttd_access_control:register_mod(auth, emqttd_mios_plugin_auth, [PubKeyFile]),
  ok = emqttd_access_control:register_mod(acl, emqttd_mios_plugin_acl, []),
  {ok, Sup}.

stop(_State) ->
  emqttd_mios_plugin:unload().