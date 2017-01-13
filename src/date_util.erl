%%%-------------------------------------------------------------------
%%% @author nico
%%% @copyright (C) 2017, <COMPANY>
%%% @doc
%%%
%%% @end
%%% Created : 13. Jan 2017 04:15 PM
%%%-------------------------------------------------------------------
-module(date_util).
-author("nico").

-define(DATETIME(),
  lists:flatten(io_lib:format("~4..0w-~2..0w-~2..0w ~2..0w:~2..0w:~2..0w:~3..0w",getDateTime()))).

%% API


getDateTime()->
  Milliseconds = erlang:system_time() div 1000000,
  Seconds = Milliseconds div 1000,
  Ms = Milliseconds - Seconds,
  BaseDate      = calendar:datetime_to_gregorian_seconds({{1970,1,1},{0,0,0}}),
  SecondsTime = BaseDate + Seconds,
  {Date,Time} = calendar:gregorian_seconds_to_datetime(SecondsTime),
  [element(1,Date), element(2,Date), element(3,Date),element(1,Time), element(2,Time), element(3,Time),Ms].

