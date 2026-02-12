%%% @doc register_identity_v1 command
%%% Command to register a new agent identity in the system.
-module(register_identity_v1).

-export([new/5, to_map/1, from_map/1]).
-export([get_mri/1, get_public_key/1, get_key_type/1, get_metadata/1, get_registered_at/1]).

-record(register_identity_v1, {
    mri :: binary(),              % Macula Resource Identifier
    public_key :: binary(),       % Public key (base64 encoded)
    key_type :: binary(),         % Key type (e.g., <<"ed25519">>)
    metadata :: map(),            % Additional metadata
    registered_at :: integer()    % Timestamp
}).

-opaque register_identity_v1() :: #register_identity_v1{}.
-export_type([register_identity_v1/0]).

%% @doc Create a new register_identity command.
-spec new(binary(), binary(), binary(), map(), integer()) -> register_identity_v1().
new(MRI, PublicKey, KeyType, Metadata, RegisteredAt) ->
    #register_identity_v1{
        mri = MRI,
        public_key = PublicKey,
        key_type = KeyType,
        metadata = Metadata,
        registered_at = RegisteredAt
    }.

%% @doc Convert command to map.
-spec to_map(register_identity_v1()) -> map().
to_map(#register_identity_v1{
    mri = MRI,
    public_key = PublicKey,
    key_type = KeyType,
    metadata = Metadata,
    registered_at = RegisteredAt
}) ->
    #{
        mri => MRI,
        public_key => PublicKey,
        key_type => KeyType,
        metadata => Metadata,
        registered_at => RegisteredAt
    }.

%% @doc Create command from map.
-spec from_map(map()) -> {ok, register_identity_v1()} | {error, term()}.
from_map(#{
    mri := MRI,
    public_key := PublicKey,
    key_type := KeyType,
    registered_at := RegisteredAt
} = Map) ->
    Metadata = maps:get(metadata, Map, #{}),
    {ok, #register_identity_v1{
        mri = MRI,
        public_key = PublicKey,
        key_type = KeyType,
        metadata = Metadata,
        registered_at = RegisteredAt
    }};
from_map(_) ->
    {error, invalid_register_identity_command}.

%% Accessor functions
get_mri(#register_identity_v1{mri = M}) -> M.
get_public_key(#register_identity_v1{public_key = P}) -> P.
get_key_type(#register_identity_v1{key_type = K}) -> K.
get_metadata(#register_identity_v1{metadata = M}) -> M.
get_registered_at(#register_identity_v1{registered_at = R}) -> R.
