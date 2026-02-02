%%% @doc capability_revoked_v1 event
%%% Emitted when a UCAN capability is successfully revoked.
-module(capability_revoked_v1).

-export([new/3, to_map/1, from_map/1]).
-export([get_capability_id/1, get_revoker/1, get_revoked_at/1]).

-record(capability_revoked_v1, {
    capability_id :: binary(),
    revoker :: binary(),
    revoked_at :: integer()
}).

-opaque capability_revoked_v1() :: #capability_revoked_v1{}.
-export_type([capability_revoked_v1/0]).

%% @doc Create a new capability_revoked event.
-spec new(binary(), binary(), integer()) -> capability_revoked_v1().
new(CapabilityId, Revoker, RevokedAt) ->
    #capability_revoked_v1{
        capability_id = CapabilityId,
        revoker = Revoker,
        revoked_at = RevokedAt
    }.

%% @doc Convert event to map.
-spec to_map(capability_revoked_v1()) -> map().
to_map(#capability_revoked_v1{
    capability_id = CapId,
    revoker = Revoker,
    revoked_at = RevokedAt
}) ->
    #{
        event_type => <<"capability_revoked_v1">>,
        capability_id => CapId,
        revoker => Revoker,
        revoked_at => RevokedAt
    }.

%% @doc Create event from map.
-spec from_map(map()) -> {ok, capability_revoked_v1()} | {error, term()}.
from_map(#{
    capability_id := CapId,
    revoker := Revoker,
    revoked_at := RevokedAt
}) ->
    {ok, #capability_revoked_v1{
        capability_id = CapId,
        revoker = Revoker,
        revoked_at = RevokedAt
    }};
from_map(_) ->
    {error, invalid_capability_revoked_event}.

%% Accessor functions
get_capability_id(#capability_revoked_v1{capability_id = C}) -> C.
get_revoker(#capability_revoked_v1{revoker = R}) -> R.
get_revoked_at(#capability_revoked_v1{revoked_at = R}) -> R.
