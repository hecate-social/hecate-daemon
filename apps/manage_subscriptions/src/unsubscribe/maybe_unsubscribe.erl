%%% @doc Handler for unsubscribe command
-module(maybe_unsubscribe).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle unsubscribe command - validates and creates unsubscribed event.
%%
%% Business rules:
%% - Agent identity must be provided
%% - Topic must be provided and non-empty
-spec handle(unsubscribe_v1:unsubscribe_v1()) -> {ok, [map()]} | {error, agent_identity_required | topic_required}.
handle(Command) ->
    #{
        agent_identity := AgentIdentity,
        topic := Topic,
        unsubscribed_at := UnsubscribedAt
    } = unsubscribe_v1:to_map(Command),

    case validate_unsubscribe(AgentIdentity, Topic) of
        ok ->
            Event = unsubscribed_v1:new(AgentIdentity, Topic, UnsubscribedAt),
            {ok, [unsubscribed_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_unsubscribe(binary(), binary()) -> ok | {error, agent_identity_required | topic_required}.
validate_unsubscribe(AgentIdentity, Topic) ->
    case {byte_size(AgentIdentity), byte_size(Topic)} of
        {0, _} -> {error, agent_identity_required};
        {_, 0} -> {error, topic_required};
        _ -> ok
    end.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice).
-spec dispatch(unsubscribe_v1:unsubscribe_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    AgentIdentity = maps:get(agent_identity, unsubscribe_v1:to_map(Cmd)),
    Topic = maps:get(topic, unsubscribe_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = unsubscribe_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(AgentIdentity, Topic, Timestamp),
        command_type = unsubscribe,
        aggregate_type = subscription_aggregate,
        aggregate_id = AgentIdentity,
        payload = CmdMap#{command_type => unsubscribe},
        metadata = #{timestamp => Timestamp},
        causation_id = undefined,
        correlation_id = undefined
    },

    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => manage_subscriptions_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

generate_cmd_id(AgentId, Topic, Ts) ->
    Hash = crypto:hash(sha256, <<AgentId/binary, Topic/binary, (integer_to_binary(Ts))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    <<"cmd-unsubscribe-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
