%%% @doc Handler for register_identity command
-module(maybe_register_identity).

-export([handle/1, handle_from_map/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle register_identity from a plain map payload.
-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{mri := MRI, public_key := PublicKey} = Payload) ->
    KeyType = maps:get(key_type, Payload, <<"ed25519">>),
    Metadata = maps:get(metadata, Payload, #{}),
    RegisteredAt = maps:get(registered_at, Payload, erlang:system_time(millisecond)),
    Cmd = register_identity_v1:new(MRI, PublicKey, KeyType, Metadata, RegisteredAt),
    handle(Cmd).

%% @doc Handle register_identity command - validates and creates identity_registered event.
%%
%% Business rules:
%% - MRI must be provided and valid format
%% - Public key must be provided
%% - Key type must be supported (ed25519, secp256k1)
-spec handle(register_identity_v1:register_identity_v1()) ->
    {ok, [map()]} | {error, mri_required | public_key_required | invalid_key_type | invalid_mri_format}.
handle(Command) ->
    #{
        mri := MRI,
        public_key := PublicKey,
        key_type := KeyType,
        metadata := Metadata,
        registered_at := RegisteredAt
    } = register_identity_v1:to_map(Command),

    case validate_identity(MRI, PublicKey, KeyType) of
        ok ->
            Event = identity_registered_v1:new(MRI, PublicKey, KeyType, Metadata, RegisteredAt),
            {ok, [identity_registered_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_identity(binary(), binary(), binary()) ->
    ok | {error, mri_required | public_key_required | invalid_key_type | invalid_mri_format}.
validate_identity(MRI, PublicKey, KeyType) ->
    case {byte_size(MRI), byte_size(PublicKey), is_valid_key_type(KeyType)} of
        {0, _, _} -> {error, mri_required};
        {_, 0, _} -> {error, public_key_required};
        {_, _, false} -> {error, invalid_key_type};
        _ ->
            case validate_mri_format(MRI) of
                ok -> ok;
                Error -> Error
            end
    end.

-spec is_valid_key_type(binary()) -> boolean().
is_valid_key_type(<<"ed25519">>) -> true;
is_valid_key_type(<<"secp256k1">>) -> true;
is_valid_key_type(_) -> false.

-spec validate_mri_format(binary()) -> ok | {error, invalid_mri_format}.
validate_mri_format(<<"mri:", _Rest/binary>>) -> ok;
validate_mri_format(_) -> {error, invalid_mri_format}.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice).
-spec dispatch(register_identity_v1:register_identity_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    MRI = maps:get(mri, register_identity_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = register_identity_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = register_identity,
        aggregate_type = node_aggregate,
        aggregate_id = MRI,
        payload = CmdMap#{command_type => register_identity},
        metadata = #{timestamp => Timestamp}
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

