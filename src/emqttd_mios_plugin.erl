%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:33 AM
%%%-------------------------------------------------------------------
-module(emqttd_mios_plugin).
-author("nico").

-include_lib("emqttd/include/emqttd.hrl").

-export([load/1, unload/0]).

%% Hooks functions

-export([on_client_disconnected/3]).


%% Called when the plugin application start
load(_Env) ->
  emqttd_mios_plugin_utils:create_tables(),
  emqttd:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, []).


on_client_disconnected(Reason, _Client = #mqtt_client{client_id = ClientId}, _Env) ->
  io:format("client ~s disconnected, reason: ~w~n", [ClientId, Reason]),
  emqttd_mios_plugin_utils:delete_client(ClientId),
  ok.


%% Called when the plugin application stop
unload() ->
  emqttd:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
  emqttd_mios_plugin_utils:delete_tables().
