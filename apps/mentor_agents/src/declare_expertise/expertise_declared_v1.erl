%%% @doc expertise_declared_v1 event
%%% Emitted when an agent declares expertise domains.
-module(expertise_declared_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_agent_id/1, get_domains/1, get_declared_at/1]).

-record(expertise_declared_v1, {
    agent_id    :: binary(),
    domains     :: [binary()],
    declared_at :: integer()
}).

-export_type([expertise_declared_v1/0]).
-opaque expertise_declared_v1() :: #expertise_declared_v1{}.

-spec new(binary(), [binary()]) -> expertise_declared_v1().
new(AgentId, Domains) ->
    #expertise_declared_v1{
        agent_id = AgentId,
        domains = Domains,
        declared_at = erlang:system_time(millisecond)
    }.

-spec to_map(expertise_declared_v1()) -> map().
to_map(#expertise_declared_v1{} = E) ->
    #{
        event_type => <<"expertise_declared_v1">>,
        agent_id => E#expertise_declared_v1.agent_id,
        domains => E#expertise_declared_v1.domains,
        declared_at => E#expertise_declared_v1.declared_at
    }.

-spec from_map(map()) -> {ok, expertise_declared_v1()} | {error, term()}.
from_map(#{agent_id := AId, domains := Doms} = Map) ->
    {ok, #expertise_declared_v1{
        agent_id = AId,
        domains = Doms,
        declared_at = maps:get(declared_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_agent_id(#expertise_declared_v1{agent_id = V}) -> V.
get_domains(#expertise_declared_v1{domains = V}) -> V.
get_declared_at(#expertise_declared_v1{declared_at = V}) -> V.
