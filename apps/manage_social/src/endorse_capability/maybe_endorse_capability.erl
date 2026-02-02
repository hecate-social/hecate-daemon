-module(maybe_endorse_capability).
-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).

handle(Command) ->
    #{endorser_identity := Endorser, capability_mri := MRI} = endorse_capability_v1:to_map(Command),
    Comment = maps:get(comment, endorse_capability_v1:to_map(Command), undefined),
    Event = capability_endorsed_v1:new(Endorser, MRI, Comment, erlang:system_time(millisecond)),
    {ok, [capability_endorsed_v1:to_map(Event)]}.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice)
-spec dispatch(endorse_capability_v1:endorse_capability_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    EndorserIdentity = maps:get(endorser_identity, endorse_capability_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = endorse_capability_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(EndorserIdentity, Timestamp),
        command_type = endorse_capability,
        aggregate_type = social_aggregate,
        aggregate_id = EndorserIdentity,
        payload = CmdMap#{command_type => endorse_capability},
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
    <<"cmd-endorse_capability-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
