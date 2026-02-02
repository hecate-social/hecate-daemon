-module(capability_endorsed_v1).
-export([new/4, to_map/1, from_map/1]).

-record(capability_endorsed_v1, {
    endorser_identity :: binary(),
    capability_mri :: binary(),
    comment :: binary() | undefined,
    endorsed_at :: integer()
}).

-opaque capability_endorsed_v1() :: #capability_endorsed_v1{}.
-export_type([capability_endorsed_v1/0]).

-spec new(binary(), binary(), binary() | undefined, integer()) -> capability_endorsed_v1().
new(EndorserIdentity, CapabilityMRI, Comment, EndorsedAt) ->
    #capability_endorsed_v1{
        endorser_identity = EndorserIdentity,
        capability_mri = CapabilityMRI,
        comment = Comment,
        endorsed_at = EndorsedAt
    }.

-spec to_map(capability_endorsed_v1()) -> map().
to_map(#capability_endorsed_v1{
    endorser_identity = Endorser,
    capability_mri = MRI,
    comment = Comment,
    endorsed_at = EndorsedAt
}) ->
    #{
        event_type => <<"capability_endorsed_v1">>,
        endorser_identity => Endorser,
        capability_mri => MRI,
        comment => Comment,
        endorsed_at => EndorsedAt
    }.

-spec from_map(map()) -> {ok, capability_endorsed_v1()} | {error, term()}.
from_map(#{
    endorser_identity := Endorser,
    capability_mri := MRI,
    endorsed_at := EndorsedAt
} = Map) ->
    Comment = maps:get(comment, Map, undefined),
    {ok, #capability_endorsed_v1{
        endorser_identity = Endorser,
        capability_mri = MRI,
        comment = Comment,
        endorsed_at = EndorsedAt
    }};
from_map(_) ->
    {error, invalid_capability_endorsed_event}.
