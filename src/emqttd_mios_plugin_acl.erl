%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:57 AM
%%%-------------------------------------------------------------------
-module(emqttd_mios_plugin_acl).
-author("nico").


-include_lib("emqttd/include/emqttd.hrl").

%% ACL callbacks
-export([init/1, check_acl/2, reload_acl/1, description/0]).

init(Opts) ->
  io:format("init: Init ACL mios plugin~n"),
  {ok, Opts}.

check_acl({#mqtt_client{client_id = ClientId, username = Username}, PubSub, Topic}, SuperUser) ->
%%  io:format("MiOS ACL: ~p ~p ~p~n", [ClientId, PubSub, Topic]),
  IsSuperUser = (SuperUser==binary_to_list(Username)),
  Allow=IsSuperUser orelse emqttd_mios_plugin_utils:check_acl(binary_to_list(ClientId),PubSub,binary_to_list(Topic)),
  if
    Allow ->
      allow;
    true ->
      deny
  end.

reload_acl(_Opts) ->
  emqttd_mios_plugin_utils:update_all_clients(),
  ok.

description() -> "MiOS ACL Module".
