-module(resolve_dispute_v1).

-export([new/5, to_map/1, from_map/1]).

-record(resolve_dispute_v1, {
    dispute_id :: binary(),
    resolver_identity :: binary(),
    resolution :: binary(),  % upheld | dismissed | mediated
    notes :: binary(),
    timestamp :: integer()
}).

-opaque resolve_dispute_v1() :: #resolve_dispute_v1{}.
-export_type([resolve_dispute_v1/0]).

-spec new(binary(), binary(), binary(), binary(), integer()) -> resolve_dispute_v1().
new(DisputeId, ResolverIdentity, Resolution, Notes, Timestamp) ->
    #resolve_dispute_v1{
        dispute_id = DisputeId,
        resolver_identity = ResolverIdentity,
        resolution = Resolution,
        notes = Notes,
        timestamp = Timestamp
    }.

-spec to_map(resolve_dispute_v1()) -> map().
to_map(#resolve_dispute_v1{
    dispute_id = DisputeId,
    resolver_identity = Resolver,
    resolution = Resolution,
    notes = Notes,
    timestamp = Timestamp
}) ->
    #{
        dispute_id => DisputeId,
        resolver_identity => Resolver,
        resolution => Resolution,
        notes => Notes,
        timestamp => Timestamp
    }.

-spec from_map(map()) -> {ok, resolve_dispute_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    resolver_identity := Resolver,
    resolution := Resolution
} = Map) ->
    Notes = maps:get(notes, Map, <<>>),
    Timestamp = maps:get(timestamp, Map, erlang:system_time(millisecond)),

    {ok, #resolve_dispute_v1{
        dispute_id = DisputeId,
        resolver_identity = Resolver,
        resolution = Resolution,
        notes = Notes,
        timestamp = Timestamp
    }};
from_map(_) ->
    {error, invalid_resolve_dispute_command}.
