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

-spec validate_grant(binary(), binary(), binary(), binary(), [binary()], integer(), integer()) ->
    ok | {error, capability_id_required | issuer_required | audience_required | resource_required | actions_required | invalid_expiration}.
validate_grant(CapId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt) ->
    case {byte_size(CapId), byte_size(Issuer), byte_size(Audience), byte_size(Resource)} of
        {0, _, _, _} -> {error, capability_id_required};
        {_, 0, _, _} -> {error, issuer_required};
        {_, _, 0, _} -> {error, audience_required};
        {_, _, _, 0} -> {error, resource_required};
        _ ->
            case Actions of
                [] -> {error, actions_required};
                _ ->
                    case ExpiresAt > GrantedAt of
                        true -> ok;
                        false -> {error, invalid_expiration}
                    end
            end
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
