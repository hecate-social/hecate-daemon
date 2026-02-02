%%% @doc Handler for subscribe command
-module(maybe_subscribe).

-export([handle/1, dispatch/1]).

%% Suppress dialyzer warnings for calls to evoq_dispatcher (excluded from PLT)
-dialyzer({nowarn_function, [dispatch/1]}).
%% Suppress supertype warning (returns specific map, spec uses map())
-dialyzer({nowarn_function, [handle/1]}).

%% @doc Handle subscribe command - validates and creates subscribed event.
%%
%% Business rules:
%% - Agent identity must be provided
%% - Topic must be provided and non-empty
%% - Filter is optional (for filtered subscriptions)
-spec handle(subscribe_v1:subscribe_v1()) -> {ok, [map()]} | {error, agent_identity_required | topic_required}.
handle(Command) ->
    #{
        agent_identity := AgentIdentity,
        topic := Topic,
        filter := Filter,
        subscribed_at := SubscribedAt
    } = subscribe_v1:to_map(Command),

    case validate_subscribe(AgentIdentity, Topic) of
        ok ->
            Event = subscribed_v1:new(AgentIdentity, Topic, Filter, SubscribedAt),
            {ok, [subscribed_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

%% Internal functions

-spec validate_subscribe(binary(), binary()) -> ok | {error, agent_identity_required | topic_required}.
validate_subscribe(AgentIdentity, Topic) ->
    case {byte_size(AgentIdentity), byte_size(Topic)} of
        {0, _} -> {error, agent_identity_required};
        {_, 0} -> {error, topic_required};
        _ -> ok
    end.

-include_lib("evoq/include/evoq.hrl").

%% @doc Dispatch command via evoq (self-contained slice).
-spec dispatch(subscribe_v1:subscribe_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    AgentIdentity = maps:get(agent_identity, subscribe_v1:to_map(Cmd)),
    Topic = maps:get(topic, subscribe_v1:to_map(Cmd)),
    Timestamp = erlang:system_time(millisecond),

    CmdMap = subscribe_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_id = generate_cmd_id(AgentIdentity, Topic, Timestamp),
        command_type = subscribe,
        aggregate_type = subscription_aggregate,
        aggregate_id = AgentIdentity,
        payload = CmdMap#{command_type => subscribe},
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
    <<"cmd-subscribe-", (integer_to_binary(Ts))/binary, "-", ShortHash/binary>>.
