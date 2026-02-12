%%% @doc Handler for subscribe_topic command.
-module(maybe_subscribe_topic).
-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{agent_identity := Agent, topic := Topic, filter := Filter, subscribed_at := At} = subscribe_topic_v1:to_map(Command),
    case {byte_size(Agent), byte_size(Topic)} of
        {0, _} -> {error, agent_identity_required};
        {_, 0} -> {error, topic_required};
        _ ->
            Event = topic_subscribed_v1:new(Agent, Topic, Filter, At),
            {ok, [topic_subscribed_v1:to_map(Event)]}
    end.

handle_from_map(Payload) ->
    Agent = maps:get(agent_identity, Payload, maps:get(<<"agent_identity">>, Payload, <<>>)),
    Topic = maps:get(topic, Payload, maps:get(<<"topic">>, Payload, <<>>)),
    Filter = maps:get(filter, Payload, maps:get(<<"filter">>, Payload, undefined)),
    At = maps:get(subscribed_at, Payload, maps:get(<<"subscribed_at">>, Payload, erlang:system_time(millisecond))),
    Cmd = subscribe_topic_v1:new(Agent, Topic, Filter, At),
    handle(Cmd).

dispatch(Cmd) ->
    #{agent_identity := Agent, topic := Topic} = subscribe_topic_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),
    CmdMap = subscribe_topic_v1:to_map(Cmd),
    Hash = crypto:hash(sha256, <<Agent/binary, Topic/binary, (integer_to_binary(Timestamp))/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 16),
    EvoqCmd = #evoq_command{
        command_id = <<"cmd-subscribe_topic-", (integer_to_binary(Timestamp))/binary, "-", ShortHash/binary>>,
        command_type = subscribe_topic,
        aggregate_type = node_aggregate,
        aggregate_id = Agent,
        payload = CmdMap#{command_type => subscribe_topic},
        metadata = #{timestamp => Timestamp}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
