%%% @doc expertise_withdrawn_v1 event
%%% Emitted when an agent withdraws expertise.
-module(expertise_withdrawn_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_agent_id/1, get_withdrawn_at/1]).

-record(expertise_withdrawn_v1, {
    agent_id     :: binary(),
    withdrawn_at :: integer()
}).

-export_type([expertise_withdrawn_v1/0]).
-opaque expertise_withdrawn_v1() :: #expertise_withdrawn_v1{}.

-spec new(binary()) -> expertise_withdrawn_v1().
new(AgentId) ->
    #expertise_withdrawn_v1{
        agent_id = AgentId,
        withdrawn_at = erlang:system_time(millisecond)
    }.

-spec to_map(expertise_withdrawn_v1()) -> map().
to_map(#expertise_withdrawn_v1{} = E) ->
    #{
        event_type => <<"expertise_withdrawn_v1">>,
        agent_id => E#expertise_withdrawn_v1.agent_id,
        withdrawn_at => E#expertise_withdrawn_v1.withdrawn_at
    }.

-spec from_map(map()) -> {ok, expertise_withdrawn_v1()} | {error, term()}.
from_map(#{agent_id := AId} = Map) ->
    {ok, #expertise_withdrawn_v1{
        agent_id = AId,
        withdrawn_at = maps:get(withdrawn_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_agent_id(#expertise_withdrawn_v1{agent_id = V}) -> V.
get_withdrawn_at(#expertise_withdrawn_v1{withdrawn_at = V}) -> V.
