%%% @doc Event: A dispute against me was recorded
-module(dispute_against_me_recorded_v1).
-export([new/7, to_map/1, from_map/1]).

-record(dispute_against_me_recorded_v1, {
    dispute_id :: binary(),
    flagger_identity :: binary(),
    my_identity :: binary(),
    call_id :: binary() | undefined,
    reason :: binary(),
    flagged_at :: integer(),
    recorded_at :: integer()
}).

-opaque dispute_against_me_recorded_v1() :: #dispute_against_me_recorded_v1{}.
-export_type([dispute_against_me_recorded_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, binary(), integer(), integer()) -> dispute_against_me_recorded_v1().
new(DisputeId, FlaggerIdentity, MyIdentity, CallId, Reason, FlaggedAt, RecordedAt) ->
    #dispute_against_me_recorded_v1{
        dispute_id = DisputeId,
        flagger_identity = FlaggerIdentity,
        my_identity = MyIdentity,
        call_id = CallId,
        reason = Reason,
        flagged_at = FlaggedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(dispute_against_me_recorded_v1()) -> map().
to_map(#dispute_against_me_recorded_v1{
    dispute_id = DisputeId,
    flagger_identity = Flagger,
    my_identity = MyIdentity,
    call_id = CallId,
    reason = Reason,
    flagged_at = FlaggedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"dispute_against_me_recorded_v1">>,
        dispute_id => DisputeId,
        flagger_identity => Flagger,
        my_identity => MyIdentity,
        call_id => CallId,
        reason => Reason,
        flagged_at => FlaggedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, dispute_against_me_recorded_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    flagger_identity := Flagger,
    my_identity := MyIdentity,
    reason := Reason,
    flagged_at := FlaggedAt,
    recorded_at := RecordedAt
} = Map) ->
    CallId = maps:get(call_id, Map, undefined),
    {ok, #dispute_against_me_recorded_v1{
        dispute_id = DisputeId,
        flagger_identity = Flagger,
        my_identity = MyIdentity,
        call_id = CallId,
        reason = Reason,
        flagged_at = FlaggedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_dispute_against_me_recorded_event}.
