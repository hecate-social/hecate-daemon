%%% @doc Mesh publisher for agent_unfollowed_v1 events.
%%% Publishes to topic: social.agent.unfollowed
-module(agent_unfollowed_v1_to_mesh).

-export([publish/1]).

%% @doc Publish agent_unfollowed_v1 event to mesh
-spec publish(map()) -> ok | {error, term()}.
publish(#{event_type := <<"agent_unfollowed_v1">>} = Event) ->
    Topic = <<"social.agent.unfollowed">>,
    hecate_mesh:publish(Topic, Event);
publish(_) ->
    {error, invalid_event}.
