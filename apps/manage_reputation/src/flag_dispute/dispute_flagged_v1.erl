-module(dispute_flagged_v1).

-export([new/6, to_map/1, from_map/1]).

-record(dispute_flagged_v1, {
    dispute_id :: binary(),
    call_id :: binary(),
    flagger_identity :: binary(),
    reason :: binary(),
    evidence :: map(),
    flagged_at :: integer()
}).

-opaque dispute_flagged_v1() :: #dispute_flagged_v1{}.
-export_type([dispute_flagged_v1/0]).

-spec new(binary(), binary(), binary(), binary(), map(), integer()) -> dispute_flagged_v1().
new(DisputeId, CallId, FlaggerIdentity, Reason, Evidence, FlaggedAt) ->
    #dispute_flagged_v1{
        dispute_id = DisputeId,
        call_id = CallId,
        flagger_identity = FlaggerIdentity,
        reason = Reason,
        evidence = Evidence,
        flagged_at = FlaggedAt
    }.

-spec to_map(dispute_flagged_v1()) -> map().
to_map(#dispute_flagged_v1{
    dispute_id = DisputeId,
    call_id = CallId,
    flagger_identity = Flagger,
    reason = Reason,
    evidence = Evidence,
    flagged_at = FlaggedAt
}) ->
    #{
        event_type => <<"dispute_flagged_v1">>,
        dispute_id => DisputeId,
        call_id => CallId,
        flagger_identity => Flagger,
        reason => Reason,
        evidence => Evidence,
        flagged_at => FlaggedAt
    }.

-spec from_map(map()) -> {ok, dispute_flagged_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    call_id := CallId,
    flagger_identity := Flagger,
    reason := Reason,
    flagged_at := FlaggedAt
} = Map) ->
    Evidence = maps:get(evidence, Map, #{}),

    {ok, #dispute_flagged_v1{
        dispute_id = DisputeId,
        call_id = CallId,
        flagger_identity = Flagger,
        reason = Reason,
        evidence = Evidence,
        flagged_at = FlaggedAt
    }};
from_map(_) ->
    {error, invalid_dispute_flagged_event}.
