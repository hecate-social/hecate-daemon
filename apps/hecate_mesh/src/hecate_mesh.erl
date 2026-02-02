-module(hecate_mesh).

%% Public API for mesh operations
-export([
    publish/2,           %% Alias for publish_event
    publish_event/2,
    subscribe_to_events/0,
    get_client/0,
    is_connected/0
]).

%% @doc Publish a domain event to the mesh.
-spec publish(binary(), map()) -> ok | {error, term()}.
publish(Topic, EventData) ->
    hecate_mesh_publisher:publish_event(Topic, EventData).

%% @doc Publish a domain event to the mesh (alias for publish/2).
-spec publish_event(binary(), map()) -> ok | {error, term()}.
publish_event(EventType, EventData) ->
    publish(EventType, EventData).

%% @doc DEPRECATED: This function is a no-op.
%% Each domain owns its own listeners - there is NO central mesh subscriber.
%% See CLAUDE.md → 'MESH INTEGRATION DOCTRINE' for the correct pattern:
%% - query_capabilities → remote_capabilities_listener
%% - manage_social → follower_events_listener, endorsement_events_listener
%% - etc.
-spec subscribe_to_events() -> ok.
subscribe_to_events() ->
    ok.

%% @doc Get the mesh client pid.
-spec get_client() -> {ok, pid()} | {error, term()}.
get_client() ->
    hecate_mesh_client:get_client().

%% @doc Check if connected to mesh.
-spec is_connected() -> boolean().
is_connected() ->
    case hecate_mesh_client:get_client() of
        {ok, Pid} when is_pid(Pid) -> true;
        _ -> false
    end.
