-module(flag_dispute_v1).

-export([new/5, to_map/1, from_map/1]).

-record(flag_dispute_v1, {
    call_id :: binary(),
    flagger_identity :: binary(),
    reason :: binary(),
    evidence :: map(),
    timestamp :: integer()
}).

-opaque flag_dispute_v1() :: #flag_dispute_v1{}.
-export_type([flag_dispute_v1/0]).

-spec new(binary(), binary(), binary(), map(), integer()) -> flag_dispute_v1().
new(CallId, FlaggerIdentity, Reason, Evidence, Timestamp) ->
    #flag_dispute_v1{
        call_id = CallId,
        flagger_identity = FlaggerIdentity,
        reason = Reason,
        evidence = Evidence,
        timestamp = Timestamp
    }.

-spec to_map(flag_dispute_v1()) -> map().
to_map(#flag_dispute_v1{
    call_id = CallId,
    flagger_identity = Flagger,
    reason = Reason,
    evidence = Evidence,
    timestamp = Timestamp
}) ->
    #{
        call_id => CallId,
        flagger_identity => Flagger,
        reason => Reason,
        evidence => Evidence,
        timestamp => Timestamp
    }.

-spec from_map(map()) -> {ok, flag_dispute_v1()} | {error, term()}.
from_map(#{
    call_id := CallId,
    flagger_identity := Flagger,
    reason := Reason
} = Map) ->
    Evidence = maps:get(evidence, Map, #{}),
    Timestamp = maps:get(timestamp, Map, erlang:system_time(millisecond)),

    {ok, #flag_dispute_v1{
        call_id = CallId,
        flagger_identity = Flagger,
        reason = Reason,
        evidence = Evidence,
        timestamp = Timestamp
    }};
from_map(_) ->
    {error, invalid_flag_dispute_command}.
