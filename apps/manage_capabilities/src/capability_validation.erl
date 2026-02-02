%%% @doc Capability validation helpers
%%% Centralized validation logic for capability commands.
%%% Uses pure Erlang validation (no NIF dependency for portability).
-module(capability_validation).

-export([
    validate_mri/1,
    validate_agent_identity/1,
    validate_tags/1,
    is_owner/2
]).

%% Valid MRI types for capabilities
-define(VALID_CAP_TYPES, [<<"capability">>, <<"proc">>]).

%% @doc Validate MRI format.
%% MRI must be of type 'capability' or 'proc' (for procedures).
%% Format: mri:{type}:{realm}[/{path}]
-spec validate_mri(binary()) -> ok | {error, invalid_mri | invalid_mri_type}.
validate_mri(MRI) when is_binary(MRI) ->
    case parse_mri_simple(MRI) of
        {ok, Type, _Realm, _Path} ->
            case lists:member(Type, ?VALID_CAP_TYPES) of
                true -> ok;
                false -> {error, invalid_mri_type}
            end;
        {error, _} ->
            {error, invalid_mri}
    end;
validate_mri(_) ->
    {error, invalid_mri}.

%% @doc Validate agent identity format.
%% Agent identity should be a valid MRI of type 'agent' or a DID.
-spec validate_agent_identity(binary()) -> ok | {error, invalid_agent_identity}.
validate_agent_identity(AgentID) when is_binary(AgentID), byte_size(AgentID) > 0 ->
    case AgentID of
        <<"mri:agent:", Rest/binary>> when byte_size(Rest) > 0 ->
            %% Basic check that there's content after mri:agent:
            ok;
        <<"did:", Rest/binary>> when byte_size(Rest) > 0 ->
            %% DID format - accept any non-empty did:*
            ok;
        _ ->
            {error, invalid_agent_identity}
    end;
validate_agent_identity(_) ->
    {error, invalid_agent_identity}.

%% @doc Validate tags format.
%% Tags must be a list of non-empty binaries.
-spec validate_tags([binary()]) -> ok | {error, invalid_tags}.
validate_tags(Tags) when is_list(Tags) ->
    case lists:all(fun is_valid_tag/1, Tags) of
        true -> ok;
        false -> {error, invalid_tags}
    end;
validate_tags(_) ->
    {error, invalid_tags}.

%% @doc Check if agent is the owner of a capability.
%% Used for update/retract permission checks.
-spec is_owner(binary(), binary()) -> boolean().
is_owner(AgentID, OwnerID) when is_binary(AgentID), is_binary(OwnerID) ->
    AgentID =:= OwnerID;
is_owner(_, _) ->
    false.

%% Internal functions

%% @doc Simple MRI parser (pure Erlang, no NIF dependency).
%% Returns {ok, Type, Realm, Path} or {error, invalid_format}.
-spec parse_mri_simple(binary()) -> {ok, binary(), binary(), binary()} | {error, invalid_format}.
parse_mri_simple(<<"mri:", Rest/binary>>) ->
    case binary:split(Rest, <<":">>) of
        [Type, RealmPath] when byte_size(Type) > 0 ->
            case binary:split(RealmPath, <<"/">>) of
                [Realm] when byte_size(Realm) > 0 ->
                    {ok, Type, Realm, <<>>};
                [Realm, Path] when byte_size(Realm) > 0 ->
                    {ok, Type, Realm, Path};
                _ ->
                    {error, invalid_format}
            end;
        _ ->
            {error, invalid_format}
    end;
parse_mri_simple(_) ->
    {error, invalid_format}.

is_valid_tag(Tag) when is_binary(Tag), byte_size(Tag) > 0 ->
    %% Tags should be lowercase alphanumeric with hyphens/underscores
    %% For now, just check non-empty binary
    true;
is_valid_tag(_) ->
    false.
