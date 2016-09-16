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
-import(proplists, [get_value/3]).

-record(state, {certificate}).

get_public_key(Opts)->
  PublicKeyFile = "/home/nico/Downloads/Skype/pubkey.pem",
  PublicKey = emqttd_mios_plugin_utils:load_key(PublicKeyFile),
  PublicKey.
%%  PublicKeyFile = get_value(certificate, Opts, "default_pubkey.pem"),
%%  io:format("PublicKeyFile: ~p~n",[PublicKeyFile]),
%%  Verify= gen_conf:value(emqttd_mios_plugin, verify),
%%  if
%%    Verify==false ->
%%      no_verify;
%%    true->
%%      PublicKey = emqttd_mios_plugin_utils:load_key(PublicKeyFile),
%%      PublicKey
%%  end.


init(Opts) ->
  PublicKey=get_public_key(Opts),
  io:format("init mios~n"),

  {ok,#state{certificate = PublicKey}}.

check(_Client,Username,Password) when Username==undefined orelse Password==undefined ->
  {error,undefined_credentials};
check(#mqtt_client{client_id = ClientId, username = Username}, Password,#state{certificate = PublicKey}) ->
  io:format("MiOS Auth: clientId=~p, username=~p, password=~p~n",
    [ClientId, Username, Password]),
  emqttd_mios_plugin_utils:check_auth(PublicKey,binary_to_list(Username),Password,binary_to_list(ClientId)).

description() -> "MiOS Auth Module".