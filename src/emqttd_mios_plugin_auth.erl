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

-record(state, {pubkey}).
-import(proplists, [get_value/2, get_value/3]).

init(Opts) ->
  PublicKeyFile = get_value(pubkey, Opts, "pubkey.pem"),
  VerifySignature = get_value(verify,Opts,true),
  if
    VerifySignature==false ->
      PublicKey=no_verify,
      {ok, #state{pubkey = PublicKey}};
    true ->
      PublicKey = emqttd_mios_plugin_utils:load_key(PublicKeyFile),
      {ok, #state{pubkey = PublicKey}}
  end.

check(#mqtt_client{client_id = ClientId, username = Username}, Password,
    #state{pubkey = PublicKey}) ->
  io:format("MiOS Auth: clientId=~p, username=~p, password=~p~n",
    [ClientId, Username, Password]),
  emqttd_mios_plugin_utils:check_auth(PublicKey,Username,Password,ClientId).

description() -> "MiOS Auth Module".