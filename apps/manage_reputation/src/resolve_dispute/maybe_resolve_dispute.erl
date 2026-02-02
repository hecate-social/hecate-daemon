-module(maybe_resolve_dispute).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle resolve_dispute command - resolves a flagged dispute.
%%
%% Business rules:
%% - Resolution must be one of: upheld | dismissed | mediated
%% - Notes are optional
-spec handle(resolve_dispute_v1:resolve_dispute_v1()) ->
    {ok, [map()]} | {error, dispute_id_required | resolver_identity_required | invalid_resolution}.
handle(Command) ->
    #{
        dispute_id := DisputeId,
        resolver_identity := Resolver,
        resolution := Resolution,
        notes := Notes,
        timestamp := Timestamp
    } = resolve_dispute_v1:to_map(Command),

    case validate_resolve_dispute(DisputeId, Resolver, Resolution) of
        ok ->
            Event = dispute_resolved_v1:new(
                DisputeId,
                Resolver,
                Resolution,
                Notes,
                Timestamp
            ),

            {ok, [dispute_resolved_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_resolve_dispute(binary(), binary(), binary()) ->
    ok | {error, dispute_id_required | resolver_identity_required | invalid_resolution}.
validate_resolve_dispute(DisputeId, Resolver, Resolution) ->
    case {byte_size(DisputeId), byte_size(Resolver), is_valid_resolution(Resolution)} of
        {0, _, _} -> {error, dispute_id_required};
        {_, 0, _} -> {error, resolver_identity_required};
        {_, _, false} -> {error, invalid_resolution};
        _ -> ok
    end.

-spec is_valid_resolution(binary()) -> boolean().
is_valid_resolution(<<"upheld">>) -> true;
is_valid_resolution(<<"dismissed">>) -> true;
is_valid_resolution(<<"mediated">>) -> true;
is_valid_resolution(_) -> false.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(resolve_dispute_v1:resolve_dispute_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    DisputeId = maps:get(dispute_id, resolve_dispute_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(DisputeId, Timestamp),
        command_type = resolve_dispute,
        aggregate_type = reputation_aggregate,
        aggregate_id = DisputeId,
        payload = maps:merge(resolve_dispute_v1:to_map(Cmd), #{command_type => resolve_dispute}),
        metadata = #{timestamp => Timestamp},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_reputation_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-resolve_dispute-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
