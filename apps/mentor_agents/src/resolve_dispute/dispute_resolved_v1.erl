%%% @doc dispute_resolved_v1 event
%%% Emitted when a dispute on a learning is resolved.
-module(dispute_resolved_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_learning_id/1, get_resolver_id/1, get_resolution/1, get_resolved_at/1]).

-record(dispute_resolved_v1, {
    learning_id :: binary(),
    resolver_id :: binary(),
    resolution  :: binary() | undefined,
    resolved_at :: integer()
}).

-export_type([dispute_resolved_v1/0]).
-opaque dispute_resolved_v1() :: #dispute_resolved_v1{}.

-spec new(binary(), binary(), binary() | undefined) -> dispute_resolved_v1().
new(LearningId, ResolverId, Resolution) ->
    #dispute_resolved_v1{
        learning_id = LearningId,
        resolver_id = ResolverId,
        resolution = Resolution,
        resolved_at = erlang:system_time(millisecond)
    }.

-spec to_map(dispute_resolved_v1()) -> map().
to_map(#dispute_resolved_v1{} = E) ->
    #{
        event_type => <<"dispute_resolved_v1">>,
        learning_id => E#dispute_resolved_v1.learning_id,
        resolver_id => E#dispute_resolved_v1.resolver_id,
        resolution => E#dispute_resolved_v1.resolution,
        resolved_at => E#dispute_resolved_v1.resolved_at
    }.

-spec from_map(map()) -> {ok, dispute_resolved_v1()} | {error, term()}.
from_map(#{learning_id := LId, resolver_id := RId} = Map) ->
    {ok, #dispute_resolved_v1{
        learning_id = LId,
        resolver_id = RId,
        resolution = maps:get(resolution, Map, undefined),
        resolved_at = maps:get(resolved_at, Map, erlang:system_time(millisecond))
    }};
from_map(_) ->
    {error, invalid_event}.

get_learning_id(#dispute_resolved_v1{learning_id = V}) -> V.
get_resolver_id(#dispute_resolved_v1{resolver_id = V}) -> V.
get_resolution(#dispute_resolved_v1{resolution = V}) -> V.
get_resolved_at(#dispute_resolved_v1{resolved_at = V}) -> V.
