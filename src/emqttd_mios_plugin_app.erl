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


start(_StartType, _StartArgs) ->
  gen_conf:init(emqttd_mios_plugin),
  {ok, Sup} = emqttd_mios_plugin_sup:start_link(),
  Env=gen_conf:value(emqttd_mios_plugin,mios),
  emqttd_mios_plugin:load([]),
  ok = emqttd_access_control:register_mod(auth, emqttd_mios_plugin_auth, Env),
  ok = emqttd_access_control:register_mod(acl, emqttd_mios_plugin_acl, []),
  {ok, Sup}.

stop(_State) ->
  emqttd_mios_plugin:unload().