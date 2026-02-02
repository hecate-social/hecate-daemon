-module(endorse_capability_v1).
-export([new/3, to_map/1, from_map/1]).

-record(endorse_capability_v1, {
    endorser_identity :: binary(),
    capability_mri :: binary(),
    comment :: binary() | undefined
}).

-opaque endorse_capability_v1() :: #endorse_capability_v1{}.
-export_type([endorse_capability_v1/0]).

-spec new(binary(), binary(), binary() | undefined) -> endorse_capability_v1().
new(EndorserIdentity, CapabilityMRI, Comment) ->
    #endorse_capability_v1{
        endorser_identity = EndorserIdentity,
        capability_mri = CapabilityMRI,
        comment = Comment
    }.

-spec to_map(endorse_capability_v1()) -> map().
to_map(#endorse_capability_v1{endorser_identity = Endorser, capability_mri = MRI, comment = Comment}) ->
    #{
        endorser_identity => Endorser,
        capability_mri => MRI,
        comment => Comment
    }.

-spec from_map(map()) -> {ok, endorse_capability_v1()} | {error, term()}.
from_map(#{endorser_identity := Endorser, capability_mri := MRI} = Map) ->
    Comment = maps:get(comment, Map, undefined),
    {ok, #endorse_capability_v1{endorser_identity = Endorser, capability_mri = MRI, comment = Comment}};
from_map(_) ->
    {error, invalid_endorse_capability_command}.
