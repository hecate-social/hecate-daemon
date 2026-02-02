%%% @doc Mesh publisher for capability_endorsed_v1 events.
%%% Publishes to topic: social.capability.endorsed
-module(capability_endorsed_v1_to_mesh).

-export([publish/1]).

%% @doc Publish capability_endorsed_v1 event to mesh
-spec publish(map()) -> ok | {error, term()}.
publish(#{event_type := <<"capability_endorsed_v1">>} = Event) ->
    Topic = <<"social.capability.endorsed">>,
    hecate_mesh:publish(Topic, Event);
publish(_) ->
    {error, invalid_event}.
