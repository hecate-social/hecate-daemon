%%% @doc Handler for grant_ucan command.
-module(maybe_grant_ucan).
-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).
-include_lib("evoq/include/evoq.hrl").

-define(VALID_ACTIONS, [<<"read">>, <<"write">>, <<"execute">>, <<"admin">>,
                        <<"delegate">>, <<"invoke">>, <<"subscribe">>]).

handle(Command) ->
    #{
        capability_id := CapId, issuer := Issuer, audience := Audience,
        resource := Resource, actions := Actions, expires_at := ExpiresAt,
        granted_at := GrantedAt
    } = grant_ucan_v1:to_map(Command),

    case validate_grant(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) of
        ok ->
            Event = ucan_granted_v1:new(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt),
            {ok, [ucan_granted_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

handle_from_map(Payload) ->
    Get = fun(K, KB) -> maps:get(K, Payload, maps:get(KB, Payload, <<>>)) end,
    GetI = fun(K, KB) -> maps:get(K, Payload, maps:get(KB, Payload, 0)) end,
    GetL = fun(K, KB) -> maps:get(K, Payload, maps:get(KB, Payload, [])) end,
    Cmd = grant_ucan_v1:new(
        Get(capability_id, <<"capability_id">>),
        Get(issuer, <<"issuer">>),
        Get(audience, <<"audience">>),
        Get(resource, <<"resource">>),
        GetL(actions, <<"actions">>),
        GetI(expires_at, <<"expires_at">>),
        GetI(granted_at, <<"granted_at">>)
    ),
    handle(Cmd).

dispatch(Cmd) ->
    #{capability_id := CapId} = grant_ucan_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),
    CmdMap = grant_ucan_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = grant_ucan,
        aggregate_type = node_aggregate,
        aggregate_id = CapId,
        payload = CmdMap#{command_type => grant_ucan},
        metadata = #{timestamp => Timestamp}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

%% Validation

validate_grant(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    case {byte_size(CapId), byte_size(Issuer), byte_size(Audience), byte_size(Resource)} of
        {0, _, _, _} -> {error, capability_id_required};
        {_, 0, _, _} -> {error, issuer_required};
        {_, _, 0, _} -> {error, audience_required};
        {_, _, _, 0} -> {error, resource_required};
        _ -> validate_grant_fields(Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt)
    end.

validate_grant_fields(Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    case validate_identity_mri(Issuer) of
        ok -> case validate_identity_mri(Audience) of
            ok -> case validate_resource_uri(Resource) of
                ok -> case validate_actions(Actions) of
                    ok -> case ExpiresAt > GrantedAt of
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
