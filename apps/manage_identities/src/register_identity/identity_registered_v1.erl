%%% @doc identity_registered_v1 event
%%% Emitted when a new agent identity is successfully registered.
-module(identity_registered_v1).

-export([new/5, to_map/1, from_map/1]).
-export([get_mri/1, get_public_key/1, get_key_type/1, get_metadata/1, get_registered_at/1]).

-record(identity_registered_v1, {
    mri :: binary(),
    public_key :: binary(),
    key_type :: binary(),
    metadata :: map(),
    registered_at :: integer()
}).

-opaque identity_registered_v1() :: #identity_registered_v1{}.
-export_type([identity_registered_v1/0]).

%% @doc Create a new identity_registered event.
-spec new(binary(), binary(), binary(), map(), integer()) -> identity_registered_v1().
new(MRI, PublicKey, KeyType, Metadata, RegisteredAt) ->
    #identity_registered_v1{
        mri = MRI,
        public_key = PublicKey,
        key_type = KeyType,
        metadata = Metadata,
        registered_at = RegisteredAt
    }.

%% @doc Convert event to map.
-spec to_map(identity_registered_v1()) -> map().
to_map(#identity_registered_v1{
    mri = MRI,
    public_key = PublicKey,
    key_type = KeyType,
    metadata = Metadata,
    registered_at = RegisteredAt
}) ->
    #{
        event_type => <<"identity_registered_v1">>,
        mri => MRI,
        public_key => PublicKey,
        key_type => KeyType,
        metadata => Metadata,
        registered_at => RegisteredAt
    }.

%% @doc Create event from map.
-spec from_map(map()) -> {ok, identity_registered_v1()} | {error, term()}.
from_map(#{
    mri := MRI,
    public_key := PublicKey,
    key_type := KeyType,
    registered_at := RegisteredAt
} = Map) ->
    Metadata = maps:get(metadata, Map, #{}),
    {ok, #identity_registered_v1{
        mri = MRI,
        public_key = PublicKey,
        key_type = KeyType,
        metadata = Metadata,
        registered_at = RegisteredAt
    }};
from_map(_) ->
    {error, invalid_identity_registered_event}.

%% Accessor functions
get_mri(#identity_registered_v1{mri = M}) -> M.
get_public_key(#identity_registered_v1{public_key = P}) -> P.
get_key_type(#identity_registered_v1{key_type = K}) -> K.
get_metadata(#identity_registered_v1{metadata = M}) -> M.
get_registered_at(#identity_registered_v1{registered_at = R}) -> R.
