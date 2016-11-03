%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, MiOS Ltd.
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:28 AM
%%%-------------------------------------------------------------------

%% @doc emqttd mios plugin application.
-module(emq_auth_mios_app).
-include("emq_auth_mios.hrl").
-behaviour(application).

%%-import(proplists, [get_value/3]).
%% Application callbacks
-export([start/2, stop/1]).

get_public_key()->
%%  io:format("Options: ~p~n",[Opts]),
  PublicKeyFile = application:get_env(?APP, certificate),
  io:format("PublicKeyFile: ~p~n",[PublicKeyFile]),
  Verify= application:get_env(?APP,verify),
%%  io:format("Verify: ~p~n",[Verify]),
  if
    Verify==false ->
      io:format("Signature Verification disabled~n"),
      no_verify;
    true->
      PublicKey = emq_auth_mios_utils:load_key(PublicKeyFile),
      PublicKey
  end.

get_superuser_info()->
  SuperUser =     application:get_env(?APP,superuser,no_super_user),
  SuperPassword = application:get_env(?APP,superpass,no_super_pass),
  {SuperUser,SuperPassword}.





start(_StartType, _StartArgs) ->
%%  gen_conf:init(?APP),
  {ok, Sup} = emq_auth_mios_sup:start_link(),
%%  {ok,Opts} = gen_conf:value(?APP,mios),
  PublicKey=get_public_key(),
  {SuperUser,SuperPassword}=get_superuser_info(),

  emq_auth_mios:load([]),
  ok = emqttd_access_control:register_mod(auth, emq_auth_mios_auth,
    {PublicKey, SuperUser, SuperPassword}),
  ok = emqttd_access_control:register_mod(acl, emq_auth_mios_acl,
    SuperUser),
  {ok, Sup}.

stop(_State) ->
  emq_auth_mios:unload(),
  emqttd_access_control:unregister_mod(acl, emq_auth_mios_acl),
  emqttd_access_control:unregister_mod(auth, emq_auth_mios_auth).

