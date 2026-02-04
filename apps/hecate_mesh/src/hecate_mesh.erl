-module(hecate_mesh).

%% Public API for mesh operations
-export([
    publish/2,
    subscribe/2,
    unsubscribe/1,
    get_client/0,
    is_connected/0,
    %% Legacy aliases
    publish_event/2,
    subscribe_to_events/0
]).

%% @doc Publish a message to a mesh topic.
-spec publish(binary(), map()) -> ok | {error, term()}.
publish(Topic, Payload) ->
    hecate_mesh_client:publish(Topic, Payload).

%% @doc Subscribe to a mesh topic. Callback receives messages from the topic.
-spec subscribe(binary(), fun()) -> {ok, reference()} | {error, term()}.
subscribe(Topic, Callback) ->
    hecate_mesh_client:subscribe(Topic, Callback).

%% @doc Unsubscribe from a mesh topic.
-spec unsubscribe(reference()) -> ok | {error, term()}.
unsubscribe(SubRef) ->
    hecate_mesh_client:unsubscribe(SubRef).

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

%% Legacy aliases

%% @doc Alias for publish/2.
-spec publish_event(binary(), map()) -> ok | {error, term()}.
publish_event(Topic, Payload) ->
    publish(Topic, Payload).

%% @doc DEPRECATED: No-op. Each domain owns its own listeners.
-spec subscribe_to_events() -> ok.
subscribe_to_events() ->
    ok.
