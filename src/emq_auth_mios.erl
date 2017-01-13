%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:33 AM
%%%-------------------------------------------------------------------
-module(emq_auth_mios).
-author("nico").

-include_lib("emqttd/include/emqttd.hrl").
-include("emq_auth_mios.hrl").

-export([load/1, unload/0]).

%% Hooks functions

-export([on_client_disconnected/3]).


%% Called when the plugin application start
load(Env) ->
  emq_auth_mios_utils:create_tables(),
  emqttd:hook('client.disconnected', fun ?MODULE:on_client_disconnected/3, [Env]).


on_client_disconnected(Reason, #mqtt_client{client_id = ClientId}, _Env) ->
  ?LOG_LV(?LV_WARNING,"on_client_disconnected: client ~s disconnected, reason: ~w~n", [ClientId, Reason]),
  emq_auth_mios_utils:delete_client(binary_to_list(ClientId)),
  ok.


%% Called when the plugin application stop
unload() ->
  emqttd:unhook('client.disconnected', fun ?MODULE:on_client_disconnected/3),
  emq_auth_mios_utils:delete_tables().
