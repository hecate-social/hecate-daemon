%%% @doc update_identity_v1 command
%%% Command to update an agent identity's metadata.
-module(update_identity_v1).

-export([new/3, to_map/1, from_map/1]).

-record(update_identity_v1, {
    mri :: binary(),
    metadata :: map(),
    updated_at :: integer()
}).

-opaque update_identity_v1() :: #update_identity_v1{}.
-export_type([update_identity_v1/0]).

%% @doc Create a new update_identity command.
-spec new(binary(), map(), integer()) -> update_identity_v1().
new(MRI, Metadata, UpdatedAt) ->
    #update_identity_v1{
        mri = MRI,
        metadata = Metadata,
        updated_at = UpdatedAt
    }.

%% @doc Convert command to map.
-spec to_map(update_identity_v1()) -> map().
to_map(#update_identity_v1{mri = MRI, metadata = Metadata, updated_at = UpdatedAt}) ->
    #{
        mri => MRI,
        metadata => Metadata,
        updated_at => UpdatedAt
    }.

%% @doc Create command from map.
-spec from_map(map()) -> {ok, update_identity_v1()} | {error, term()}.
from_map(#{mri := MRI, metadata := Metadata, updated_at := UpdatedAt}) ->
    {ok, #update_identity_v1{mri = MRI, metadata = Metadata, updated_at = UpdatedAt}};
from_map(_) ->
    {error, invalid_update_identity_command}.
