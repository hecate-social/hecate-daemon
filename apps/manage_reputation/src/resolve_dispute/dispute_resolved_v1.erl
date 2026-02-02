-module(dispute_resolved_v1).

-export([new/5, to_map/1, from_map/1]).

-record(dispute_resolved_v1, {
    dispute_id :: binary(),
    resolver_identity :: binary(),
    resolution :: binary(),
    notes :: binary(),
    resolved_at :: integer()
}).

-opaque dispute_resolved_v1() :: #dispute_resolved_v1{}.
-export_type([dispute_resolved_v1/0]).

-spec new(binary(), binary(), binary(), binary(), integer()) -> dispute_resolved_v1().
new(DisputeId, ResolverIdentity, Resolution, Notes, ResolvedAt) ->
    #dispute_resolved_v1{
        dispute_id = DisputeId,
        resolver_identity = ResolverIdentity,
        resolution = Resolution,
        notes = Notes,
        resolved_at = ResolvedAt
    }.

-spec to_map(dispute_resolved_v1()) -> map().
to_map(#dispute_resolved_v1{
    dispute_id = DisputeId,
    resolver_identity = Resolver,
    resolution = Resolution,
    notes = Notes,
    resolved_at = ResolvedAt
}) ->
    #{
        event_type => <<"dispute_resolved_v1">>,
        dispute_id => DisputeId,
        resolver_identity => Resolver,
        resolution => Resolution,
        notes => Notes,
        resolved_at => ResolvedAt
    }.

-spec from_map(map()) -> {ok, dispute_resolved_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    resolver_identity := Resolver,
    resolution := Resolution,
    resolved_at := ResolvedAt
} = Map) ->
    Notes = maps:get(notes, Map, <<>>),

    {ok, #dispute_resolved_v1{
        dispute_id = DisputeId,
        resolver_identity = Resolver,
        resolution = Resolution,
        notes = Notes,
        resolved_at = ResolvedAt
    }};
from_map(_) ->
    {error, invalid_dispute_resolved_event}.
