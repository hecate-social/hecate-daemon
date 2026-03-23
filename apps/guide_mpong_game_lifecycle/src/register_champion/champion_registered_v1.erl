%%% @doc champion_registered_v1 event — a node's MPong champion has been registered.
-module(champion_registered_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1, event_type/0]).

-record(champion_registered_v1, {
    node_id       :: binary(),
    name          :: binary(),
    personality   :: map(),
    registered_at :: integer()
}).

-opaque champion_registered_v1() :: #champion_registered_v1{}.
-export_type([champion_registered_v1/0]).

event_type() -> <<"champion_registered_v1">>.

new(#{node_id := NId, name := Name, personality := P, registered_at := At}) ->
    #champion_registered_v1{node_id = NId, name = Name, personality = P, registered_at = At};
new(#{node_id := NId, name := Name, personality := P}) ->
    #champion_registered_v1{node_id = NId, name = Name, personality = P,
                             registered_at = erlang:system_time(millisecond)}.

to_map(#champion_registered_v1{node_id = NId, name = Name, personality = P, registered_at = At}) ->
    #{event_type => <<"champion_registered_v1">>,
      node_id => NId, name => Name, personality => P, registered_at => At}.

from_map(#{node_id := NId, name := Name, personality := P, registered_at := At}) ->
    {ok, #champion_registered_v1{node_id = NId, name = Name, personality = P, registered_at = At}};
from_map(_) ->
    {error, invalid_champion_registered_event}.
