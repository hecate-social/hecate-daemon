%%% @doc Command: Record that someone endorsed one of my capabilities
%%% Triggered by mesh listener when social.endorsed fact targets MY_IDENTITIES capabilities
-module(record_endorsement_v1).
-export([new/5, to_map/1, from_map/1]).

-record(record_endorsement_v1, {
    endorser_identity :: binary(),
    my_capability_mri :: binary(),
    my_identity :: binary(),
    comment :: binary() | undefined,
    endorsed_at :: integer()
}).

-opaque record_endorsement_v1() :: #record_endorsement_v1{}.
-export_type([record_endorsement_v1/0]).

-spec new(binary(), binary(), binary(), binary() | undefined, integer()) -> record_endorsement_v1().
new(EndorserIdentity, MyCapabilityMri, MyIdentity, Comment, EndorsedAt) ->
    #record_endorsement_v1{
        endorser_identity = EndorserIdentity,
        my_capability_mri = MyCapabilityMri,
        my_identity = MyIdentity,
        comment = Comment,
        endorsed_at = EndorsedAt
    }.

-spec to_map(record_endorsement_v1()) -> map().
to_map(#record_endorsement_v1{
    endorser_identity = Endorser,
    my_capability_mri = CapMri,
    my_identity = MyIdentity,
    comment = Comment,
    endorsed_at = EndorsedAt
}) ->
    #{
        endorser_identity => Endorser,
        my_capability_mri => CapMri,
        my_identity => MyIdentity,
        comment => Comment,
        endorsed_at => EndorsedAt
    }.

-spec from_map(map()) -> {ok, record_endorsement_v1()} | {error, term()}.
from_map(#{
    endorser_identity := Endorser,
    my_capability_mri := CapMri,
    my_identity := MyIdentity,
    endorsed_at := EndorsedAt
} = Map) ->
    Comment = maps:get(comment, Map, undefined),
    {ok, #record_endorsement_v1{
        endorser_identity = Endorser,
        my_capability_mri = CapMri,
        my_identity = MyIdentity,
        comment = Comment,
        endorsed_at = EndorsedAt
    }};
from_map(_) ->
    {error, invalid_record_endorsement_command}.
