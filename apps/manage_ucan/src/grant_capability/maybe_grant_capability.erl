%%% @doc Handler for grant_capability command
-module(maybe_grant_capability).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle grant_capability command - validates and creates capability_granted event.
%%
%% Business rules:
%% - All fields must be provided
%% - Actions list must not be empty
%% - Expires_at must be in the future
-spec handle(grant_capability_v1:grant_capability_v1()) ->
    {ok, [map()]} | {error, capability_id_required | issuer_required | audience_required | resource_required | actions_required | invalid_expiration}.
handle(Command) ->
    #{
        capability_id := CapId,
        issuer := Issuer,
        audience := Audience,
        resource := Resource,
        actions := Actions,
        expires_at := ExpiresAt,
        granted_at := GrantedAt
    } = grant_capability_v1:to_map(Command),

    case validate_grant(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) of
        ok ->
            Event = capability_granted_v1:new(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt),
            {ok, [capability_granted_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-define(VALID_ACTIONS, [<<"read">>, <<"write">>, <<"execute">>, <<"admin">>,
                        <<"delegate">>, <<"invoke">>, <<"subscribe">>]).

-spec validate_grant(binary(), binary(), binary(), binary(), [binary()], integer(), integer()) ->
    ok | {error, capability_id_required | issuer_required | audience_required |
           resource_required | actions_required | invalid_expiration |
           invalid_issuer_mri | invalid_audience_mri | invalid_resource_uri |
           {unknown_actions, [binary()]}}.
validate_grant(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    case {byte_size(CapId), byte_size(Issuer), byte_size(Audience), byte_size(Resource)} of
        {0, _, _, _} -> {error, capability_id_required};
        {_, 0, _, _} -> {error, issuer_required};
        {_, _, 0, _} -> {error, audience_required};
        {_, _, _, 0} -> {error, resource_required};
        _ ->
            validate_grant_fields(Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt)
    end.

validate_grant_fields(Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    case validate_identity_mri(Issuer) of
        ok ->
            case validate_identity_mri(Audience) of
                ok ->
                    case validate_resource_uri(Resource) of
                        ok ->
                            case validate_actions(Actions) of
                                ok ->
                                    case ExpiresAt > GrantedAt of
                                        true -> ok;
                                        false -> {error, invalid_expiration}
                                    end;
                                Error -> Error
                            end;
                        Error -> Error
                    end;
                _ -> {error, invalid_audience_mri}
            end;
        _ -> {error, invalid_issuer_mri}
    end.

validate_identity_mri(<<"mri:agent:", _/binary>>) -> ok;
validate_identity_mri(<<"did:", _/binary>>) -> ok;
validate_identity_mri(_) -> {error, invalid_mri}.

validate_resource_uri(<<"mri:", _/binary>>) -> ok;
validate_resource_uri(<<"urn:", _/binary>>) -> ok;
validate_resource_uri(<<"https://", _/binary>>) -> ok;
validate_resource_uri(<<"http://", _/binary>>) -> ok;
validate_resource_uri(_) -> {error, invalid_resource_uri}.

validate_actions([]) -> {error, actions_required};
validate_actions(Actions) when is_list(Actions) ->
    Unknown = [A || A <- Actions, not lists:member(A, ?VALID_ACTIONS)],
    case Unknown of
        [] -> ok;
        _ -> {error, {unknown_actions, Unknown}}
    end.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice).
-spec dispatch(grant_capability_v1:grant_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CapId = maps:get(capability_id, grant_capability_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = grant_capability_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(CapId, Timestamp),
        command_type = grant_capability,
        aggregate_type = ucan_aggregate,
        aggregate_id = CapId,
        payload = CmdMap#{command_type => grant_capability},
        metadata = #{timestamp => Timestamp},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_ucan_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(CapId, Ts) ->
    Hash = crypto:hash(sha256, <<CapId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-grant_capability-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
