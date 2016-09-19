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
-include("emqttd_mios_plugin.hrl").
-behaviour(application).


%% Application callbacks
-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
  gen_conf:init(?APP),
  {ok, Sup} = emqttd_mios_plugin_sup:start_link(),
  {ok, Opts} = gen_conf:value(?APP,mios),
  emqttd_mios_plugin:load([]),
  ok = emqttd_access_control:register_mod(auth, emqttd_mios_plugin_auth, Opts),
  ok = emqttd_access_control:register_mod(acl, emqttd_mios_plugin_acl, []),
  {ok, Sup}.

stop(_State) ->
  emqttd_mios_plugin:unload().