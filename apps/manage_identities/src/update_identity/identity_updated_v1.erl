%%% @doc identity_updated_v1 event
%%% Event emitted when an agent identity's metadata is updated.
-module(identity_updated_v1).

-export([new/3, to_map/1, from_map/1]).

-record(identity_updated_v1, {
    mri :: binary(),
    metadata :: map(),
    updated_at :: integer()
}).

-opaque identity_updated_v1() :: #identity_updated_v1{}.
-export_type([identity_updated_v1/0]).

%% @doc Create a new identity_updated event.
-spec new(binary(), map(), integer()) -> identity_updated_v1().
new(MRI, Metadata, UpdatedAt) ->
    #identity_updated_v1{
        mri = MRI,
        metadata = Metadata,
        updated_at = UpdatedAt
    }.

%% @doc Convert event to map.
-spec to_map(identity_updated_v1()) -> map().
to_map(#identity_updated_v1{mri = MRI, metadata = Metadata, updated_at = UpdatedAt}) ->
    #{
        event_type => <<"identity_updated_v1">>,
        mri => MRI,
        metadata => Metadata,
        updated_at => UpdatedAt
    }.

%% @doc Create event from map.
-spec from_map(map()) -> {ok, identity_updated_v1()} | {error, term()}.
from_map(#{mri := MRI, metadata := Metadata, updated_at := UpdatedAt}) ->
    {ok, #identity_updated_v1{mri = MRI, metadata = Metadata, updated_at = UpdatedAt}};
from_map(_) ->
    {error, invalid_identity_updated_event}.
