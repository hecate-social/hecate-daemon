%%% @doc Event: A dispute resolution was recorded
-module(dispute_resolution_recorded_v1).
-export([new/7, to_map/1, from_map/1]).

-record(dispute_resolution_recorded_v1, {
    dispute_id :: binary(),
    my_identity :: binary(),
    resolution :: binary(),
    resolver_identity :: binary() | undefined,
    notes :: binary() | undefined,
    resolved_at :: integer(),
    recorded_at :: integer()
}).

-opaque dispute_resolution_recorded_v1() :: #dispute_resolution_recorded_v1{}.
-export_type([dispute_resolution_recorded_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, binary() | undefined, integer(), integer()) -> dispute_resolution_recorded_v1().
new(DisputeId, MyIdentity, Resolution, ResolverIdentity, Notes, ResolvedAt, RecordedAt) ->
    #dispute_resolution_recorded_v1{
        dispute_id = DisputeId,
        my_identity = MyIdentity,
        resolution = Resolution,
        resolver_identity = ResolverIdentity,
        notes = Notes,
        resolved_at = ResolvedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(dispute_resolution_recorded_v1()) -> map().
to_map(#dispute_resolution_recorded_v1{
    dispute_id = DisputeId,
    my_identity = MyIdentity,
    resolution = Resolution,
    resolver_identity = Resolver,
    notes = Notes,
    resolved_at = ResolvedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"dispute_resolution_recorded_v1">>,
        dispute_id => DisputeId,
        my_identity => MyIdentity,
        resolution => Resolution,
        resolver_identity => Resolver,
        notes => Notes,
        resolved_at => ResolvedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, dispute_resolution_recorded_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    my_identity := MyIdentity,
    resolution := Resolution,
    resolved_at := ResolvedAt,
    recorded_at := RecordedAt
} = Map) ->
    Resolver = maps:get(resolver_identity, Map, undefined),
    Notes = maps:get(notes, Map, undefined),
    {ok, #dispute_resolution_recorded_v1{
        dispute_id = DisputeId,
        my_identity = MyIdentity,
        resolution = Resolution,
        resolver_identity = Resolver,
        notes = Notes,
        resolved_at = ResolvedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_dispute_resolution_recorded_event}.
