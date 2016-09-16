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
  {ok, Opts}.

check_acl({Client, PubSub, Topic}, _Opts) ->
  io:format("MiOS ACL: ~p ~p ~p~n", [Client, PubSub, Topic]),
  Allow=emqttd_mios_plugin_utils:check_acl(Client,PubSub,Topic),
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
