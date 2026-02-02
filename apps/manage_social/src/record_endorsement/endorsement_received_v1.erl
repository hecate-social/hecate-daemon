%%% @doc Event: An endorsement was received (someone endorsed one of my capabilities)
-module(endorsement_received_v1).
-export([new/6, to_map/1, from_map/1]).

-record(endorsement_received_v1, {
    endorser_identity :: binary(),
    my_capability_mri :: binary(),
    my_identity :: binary(),
    comment :: binary() | undefined,
    endorsed_at :: integer(),
    recorded_at :: integer()
}).

-opaque endorsement_received_v1() :: #endorsement_received_v1{}.
-export_type([endorsement_received_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, integer(), integer()) -> endorsement_received_v1().
new(EndorserIdentity, MyCapabilityMri, MyIdentity, Comment, EndorsedAt, RecordedAt) ->
    #endorsement_received_v1{
        endorser_identity = EndorserIdentity,
        my_capability_mri = MyCapabilityMri,
        my_identity = MyIdentity,
        comment = Comment,
        endorsed_at = EndorsedAt,
        recorded_at = RecordedAt
    }.

-spec to_map(endorsement_received_v1()) -> map().
to_map(#endorsement_received_v1{
    endorser_identity = Endorser,
    my_capability_mri = CapMri,
    my_identity = MyIdentity,
    comment = Comment,
    endorsed_at = EndorsedAt,
    recorded_at = RecordedAt
}) ->
    #{
        event_type => <<"endorsement_received_v1">>,
        endorser_identity => Endorser,
        my_capability_mri => CapMri,
        my_identity => MyIdentity,
        comment => Comment,
        endorsed_at => EndorsedAt,
        recorded_at => RecordedAt
    }.

-spec from_map(map()) -> {ok, endorsement_received_v1()} | {error, term()}.
from_map(#{
    endorser_identity := Endorser,
    my_capability_mri := CapMri,
    my_identity := MyIdentity,
    endorsed_at := EndorsedAt,
    recorded_at := RecordedAt
} = Map) ->
    Comment = maps:get(comment, Map, undefined),
    {ok, #endorsement_received_v1{
        endorser_identity = Endorser,
        my_capability_mri = CapMri,
        my_identity = MyIdentity,
        comment = Comment,
        endorsed_at = EndorsedAt,
        recorded_at = RecordedAt
    }};
from_map(_) ->
    {error, invalid_endorsement_received_event}.
