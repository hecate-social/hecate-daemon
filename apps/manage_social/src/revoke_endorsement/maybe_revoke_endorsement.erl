-module(maybe_revoke_endorsement).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

handle(Command) ->
    #{endorser_identity := Endorser, capability_mri := MRI} = revoke_endorsement_v1:to_map(Command),
    Event = endorsement_revoked_v1:new(Endorser, MRI, erlang:system_time(millisecond)),
    {ok, [endorsement_revoked_v1:to_map(Event)]}.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(revoke_endorsement_v1:revoke_endorsement_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    EndorserIdentity = maps:get(endorser_identity, revoke_endorsement_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = revoke_endorsement_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(EndorserIdentity, Timestamp),
        command_type = revoke_endorsement,
        aggregate_type = social_aggregate,
        aggregate_id = EndorserIdentity,
        payload = CmdMap#{command_type => revoke_endorsement},
        metadata = #{timestamp => Timestamp},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_social_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AggId, Ts) ->
    Hash = crypto:hash(sha256, <<AggId/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-revoke_endorsement-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
