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


%% Application callbacks
-export([start/2, stop/1]).

get_public_key()->
%%  PublicKeyFile = "/home/nico/Downloads/Skype/pubkey.pem",
%%  PublicKeyFile.
  PublicKeyFile = gen_conf:value(emqttd_mios_plugin, pubkey),
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
  gen_conf:init(emqttd_mios_plugin),
  {ok, Sup} = emqttd_mios_plugin_sup:start_link(),
  emqttd_mios_plugin:load([]),
  ok = emqttd_access_control:register_mod(auth, emqttd_mios_plugin_auth, [get_public_key()]),
  ok = emqttd_access_control:register_mod(acl, emqttd_mios_plugin_acl, []),
  {ok, Sup}.

stop(_State) ->
  emqttd_mios_plugin:unload().