%%% @doc Command: Record that someone filed a dispute against one of my services
%%% Triggered by mesh listener when dispute.flagged fact targets MY_IDENTITIES
-module(record_dispute_against_me_v1).
-export([new/6, to_map/1, from_map/1]).

-record(record_dispute_against_me_v1, {
    dispute_id :: binary(),
    flagger_identity :: binary(),
    my_identity :: binary(),
    call_id :: binary() | undefined,
    reason :: binary(),
    flagged_at :: integer()
}).

-opaque record_dispute_against_me_v1() :: #record_dispute_against_me_v1{}.
-export_type([record_dispute_against_me_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, binary(), integer()) -> record_dispute_against_me_v1().
new(DisputeId, FlaggerIdentity, MyIdentity, CallId, Reason, FlaggedAt) ->
    #record_dispute_against_me_v1{
        dispute_id = DisputeId,
        flagger_identity = FlaggerIdentity,
        my_identity = MyIdentity,
        call_id = CallId,
        reason = Reason,
        flagged_at = FlaggedAt
    }.

-spec to_map(record_dispute_against_me_v1()) -> map().
to_map(#record_dispute_against_me_v1{
    dispute_id = DisputeId,
    flagger_identity = Flagger,
    my_identity = MyIdentity,
    call_id = CallId,
    reason = Reason,
    flagged_at = FlaggedAt
}) ->
    #{
        dispute_id => DisputeId,
        flagger_identity => Flagger,
        my_identity => MyIdentity,
        call_id => CallId,
        reason => Reason,
        flagged_at => FlaggedAt
    }.

-spec from_map(map()) -> {ok, record_dispute_against_me_v1()} | {error, term()}.
from_map(#{
    dispute_id := DisputeId,
    flagger_identity := Flagger,
    my_identity := MyIdentity,
    reason := Reason,
    flagged_at := FlaggedAt
} = Map) ->
    CallId = maps:get(call_id, Map, undefined),
    {ok, #record_dispute_against_me_v1{
        dispute_id = DisputeId,
        flagger_identity = Flagger,
        my_identity = MyIdentity,
        call_id = CallId,
        reason = Reason,
        flagged_at = FlaggedAt
    }};
from_map(_) ->
    {error, invalid_record_dispute_against_me_command}.
