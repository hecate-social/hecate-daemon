%%% @doc Mesh publisher for endorsement_revoked_v1 events.
%%% Publishes to topic: social.endorsement.revoked
-module(endorsement_revoked_v1_to_mesh).

-export([publish/1]).

%% @doc Publish endorsement_revoked_v1 event to mesh
-spec publish(map()) -> ok | {error, term()}.
publish(#{event_type := <<"endorsement_revoked_v1">>} = Event) ->
    Topic = <<"social.endorsement.revoked">>,
    hecate_mesh:publish(Topic, Event);
publish(_) ->
    {error, invalid_event}.
