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

-define(APP, emqttd_mios_plugin).

%% Application callbacks
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  gen_conf:init(?APP),
  {ok, Sup} = emqttd_mios_plugin_sup:start_link(),
  emqttd_mios_plugin:load([]),
  Json="{\"test\":12,\"str\":\"string\"}",
  Decoded = jiffy:decode(Json,[return_maps]),
  io:format("JsonTest: ~p~n", [Decoded]),
  ok = emqttd_access_control:register_mod(auth, emqttd_mios_plugin_auth, gen_conf:value(?APP, mios)),
  ok = emqttd_access_control:register_mod(acl, emqttd_mios_plugin_acl, []),
  {ok, Sup}.

stop(_State) ->
  emqttd_mios_plugin:unload().