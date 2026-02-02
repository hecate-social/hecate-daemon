%%% @doc Mesh publisher for identity_updated_v1 events.
%%% Publishes to topic: identity.updated
-module(identity_updated_v1_to_mesh).

-export([publish/1]).

%% @doc Publish identity_updated_v1 event to mesh
-spec publish(map()) -> ok | {error, term()}.
publish(#{event_type := <<"identity_updated_v1">>} = Event) ->
    Topic = <<"identity.updated">>,
    hecate_mesh:publish(Topic, Event);
publish(_) ->
    {error, invalid_event}.
