%%% @doc Handler for revoke_capability command
-module(maybe_revoke_capability).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle revoke_capability command - validates and creates capability_revoked event.
%%
%% Business rules:
%% - Capability ID must be provided
%% - Revoker must be provided
-spec handle(revoke_capability_v1:revoke_capability_v1()) ->
    {ok, [map()]} | {error, capability_id_required | revoker_required}.
handle(Command) ->
    #{
        capability_id := CapId,
        revoker := Revoker,
        revoked_at := RevokedAt
    } = revoke_capability_v1:to_map(Command),

    case validate_revoke(CapId, Revoker) of
        ok ->
            Event = capability_revoked_v1:new(CapId, Revoker, RevokedAt),
            {ok, [capability_revoked_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_revoke(binary(), binary()) -> ok | {error, capability_id_required | revoker_required}.
validate_revoke(CapId, Revoker) ->
    case {byte_size(CapId), byte_size(Revoker)} of
        {0, _} -> {error, capability_id_required};
        {_, 0} -> {error, revoker_required};
        _ -> ok
    end.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice).
-spec dispatch(revoke_capability_v1:revoke_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CapId = maps:get(capability_id, revoke_capability_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = revoke_capability_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(CapId, Timestamp),
        command_type = revoke_capability,
        aggregate_type = ucan_aggregate,
        aggregate_id = CapId,
        payload = CmdMap#{command_type => revoke_capability},
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
    <<"cmd-revoke_capability-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
