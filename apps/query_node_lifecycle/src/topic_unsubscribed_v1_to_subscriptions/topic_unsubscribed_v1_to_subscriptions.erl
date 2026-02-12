%%% @doc Projects topic_unsubscribed_v1 events into the subscriptions table.
-module(topic_unsubscribed_v1_to_subscriptions).
-export([project/1]).

project(Data) when is_map(Data) ->
    AgentIdentity = get_field(agent_identity, Data),
    Topic = get_field(topic, Data),

    Sql = "UPDATE subscriptions SET active = 0 "
          "WHERE agent_identity = ? AND topic = ?",
    Params = [AgentIdentity, Topic],
    query_node_lifecycle_store:execute(Sql, Params);
project(_) -> ok.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, undefined)
    end.
