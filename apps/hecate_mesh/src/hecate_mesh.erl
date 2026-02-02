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

%% @doc Subscribe to all domain events (for query services).
%% TODO: Implement proper mesh subscriber (currently a no-op).
%% The mesh subscriber pattern needs refactoring - see CLAUDE.md.
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
