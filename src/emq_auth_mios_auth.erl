%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:41 AM
%%%-------------------------------------------------------------------
-module(emq_auth_mios_auth).
-author("nico").



-behaviour(emqttd_auth_mod).
-include_lib("emqttd/include/emqttd.hrl").
-include("emq_auth_mios.hrl").
%% API
-export([init/1, check/3, description/0]).

init(Opts) ->
  ?LOG_LV(?LV_STATUS,("init: Init Auth mios plugin~n"),
  {ok,Opts}.

check(_Client,Username,Password) when Username==undefined orelse Password==undefined ->
  {error,undefined_credentials};
check(#mqtt_client{client_id = ClientId, username = Username}, Password, {PublicKey, SuperUser, SuperPassword})->
%%  ?LOG_LV(?LV_STATUS,("MiOS Auth: clientId=~p, username=~p, password=~p~n", [ClientId, Username, Password]),
%%  ?LOG_LV(?LV_STATUS,("MiOS Auth: SuperUser=~p, SuperPassword=~p~n", [SuperUser,SuperPassword]),
  IsSuperUser = (SuperUser==binary_to_list(Username)) andalso
    ((not (SuperUser == no_super_user)) andalso
    ((SuperPassword==no_super_pass) orelse (SuperPassword == binary_to_list(Password)))),
  if
    IsSuperUser ->
      ?LOG_LV(?LV_STATUS,("~p loged as superuser~n",[ClientId]),
      ok;
    true ->
      emq_auth_mios_utils:check_auth(PublicKey,binary_to_list(Username),Password,binary_to_list(ClientId))
  end.

description() -> "MiOS Auth Module".