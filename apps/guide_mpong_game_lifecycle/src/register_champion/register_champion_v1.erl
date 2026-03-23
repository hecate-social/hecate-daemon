%%% @doc register_champion_v1 command — register this node's MPong champion bot.
-module(register_champion_v1).

-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1, command_type/0]).

-record(register_champion_v1, {
    node_id     :: binary(),
    name        :: binary(),
    personality :: map()
}).

-opaque register_champion_v1() :: #register_champion_v1{}.
-export_type([register_champion_v1/0]).

command_type() -> register_champion.

new(#{node_id := NId, name := Name, personality := P}) ->
    {ok, #register_champion_v1{node_id = NId, name = Name, personality = P}};
new(_) ->
    {error, missing_fields}.

to_map(#register_champion_v1{node_id = NId, name = Name, personality = P}) ->
    #{node_id => NId, name => Name, personality => P}.

from_map(#{node_id := NId, name := Name, personality := P}) ->
    {ok, #register_champion_v1{node_id = NId, name = Name, personality = P}};
from_map(_) ->
    {error, invalid_register_champion_command}.
