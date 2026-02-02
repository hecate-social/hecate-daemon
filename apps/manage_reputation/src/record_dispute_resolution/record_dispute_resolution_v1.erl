%%% @doc Command: Record that a dispute against me was resolved
-module(record_dispute_resolution_v1).
-export([new/6, to_map/1, from_map/1]).

-record(record_dispute_resolution_v1, {
    dispute_id :: binary(),
    my_identity :: binary(),
    resolution :: binary(),          %% upheld | dismissed | withdrawn
    resolver_identity :: binary() | undefined,
    notes :: binary() | undefined,
    resolved_at :: integer()
}).

-opaque record_dispute_resolution_v1() :: #record_dispute_resolution_v1{}.
-export_type([record_dispute_resolution_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, binary() | undefined, integer()) -> record_dispute_resolution_v1().
new(DisputeId, MyIdentity, Resolution, ResolverIdentity, Notes, ResolvedAt) ->
    #record_dispute_resolution_v1{
        dispute_id = DisputeId,
        my_identity = MyIdentity,
        resolution = Resolution,
        resolver_identity = ResolverIdentity,
        notes = Notes,
        resolved_at = ResolvedAt
    }.

-spec to_map(record_dispute_resolution_v1()) -> map().
to_map(#record_dispute_resolution_v1{
    dispute_id = DisputeId,
    my_identity = MyIdentity,
    resolution = Resolution,
    resolver_identity = Resolver,
    notes = Notes,
    resolved_at = ResolvedAt
}) ->
    #{
        dispute_id => DisputeId,
        my_identity => MyIdentity,
        resolution => Resolution,
        resolver_identity => Resolver,
        notes => Notes,
        resolved_at => ResolvedAt
    }.

-spec from_map(map()) -> {ok, record_dispute_resolution_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    my_identity := MyIdentity,
    resolution := Resolution,
    resolved_at := ResolvedAt
} = Map) ->
    Resolver = maps:get(resolver_identity, Map, undefined),
    Notes = maps:get(notes, Map, undefined),
    {ok, #record_dispute_resolution_v1{
        dispute_id = DisputeId,
        my_identity = MyIdentity,
        resolution = Resolution,
        resolver_identity = Resolver,
        notes = Notes,
        resolved_at = ResolvedAt
    }};
from_map(_) ->
    {error, invalid_record_dispute_resolution_command}.
