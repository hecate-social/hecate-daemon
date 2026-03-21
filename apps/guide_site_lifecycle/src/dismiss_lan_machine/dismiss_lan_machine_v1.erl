%%% @doc dismiss_lan_machine_v1 command
-module(dismiss_lan_machine_v1).

-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).

-record(dismiss_lan_machine_v1, {
    mac :: binary()
}).

-opaque dismiss_lan_machine_v1() :: #dismiss_lan_machine_v1{}.
-export_type([dismiss_lan_machine_v1/0]).

command_type() -> dismiss_lan_machine.

new(MAC) ->
    #dismiss_lan_machine_v1{mac = MAC}.

-spec to_map(dismiss_lan_machine_v1()) -> map().
to_map(#dismiss_lan_machine_v1{mac = MAC}) ->
    #{mac => MAC}.

-spec from_map(map()) -> {ok, dismiss_lan_machine_v1()} | {error, term()}.
from_map(#{mac := MAC}) ->
    {ok, #dismiss_lan_machine_v1{mac = MAC}};
from_map(_) ->
    {error, invalid_dismiss_command}.
