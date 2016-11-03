%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2016, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 16. Sep 2016 07:31 AM
%%%-------------------------------------------------------------------
-module(emq_auth_mios_sup).
-author("nico").

%% API
-export([start_link/0]).

%% Supervisor callbacks
-export([init/1]).

start_link() ->
  supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
  {ok, { {one_for_one, 5, 10}, []} }.
