%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:41 AM
%%%-------------------------------------------------------------------
-module(emqttd_mios_plugin_auth).
-author("nico").


-behaviour(emqttd_auth_mod).

-include_lib("emqttd/include/emqttd.hrl").

%% API
-export([init/1, check/3, description/0]).

-import(proplists, [get_value/2, get_value/3]).

init(Opts) ->
  io:fwrite("init mios~n"),

  {ok,Opts}.

check(#mqtt_client{client_id = ClientId, username = Username}, Password,[PublicKey]) ->
  io:format("MiOS Auth: clientId=~p, username=~p, password=~p~n",
    [ClientId, Username, Password]),
  emqttd_mios_plugin_utils:check_auth(PublicKey,Username,Password,ClientId).

description() -> "MiOS Auth Module".