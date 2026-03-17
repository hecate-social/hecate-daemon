-module(hecate_mesh).

-export([
    publish/2,
    subscribe/2,
    unsubscribe/1,
    get_client/0,
    get_status/0,
    is_connected/0,
    discover_subscribers/1
]).

-spec publish(binary(), map()) -> ok | {error, term()}.
publish(Topic, Payload) ->
    hecate_mesh_client:publish(Topic, Payload).

-spec subscribe(binary(), fun()) -> {ok, reference()} | {error, term()}.
subscribe(Topic, Callback) ->
    hecate_mesh_client:subscribe(Topic, Callback).

-spec unsubscribe(reference()) -> ok | {error, term()}.
unsubscribe(SubRef) ->
    hecate_mesh_client:unsubscribe(SubRef).

-spec get_client() -> {ok, pid()} | {error, term()}.
get_client() ->
    hecate_mesh_client:get_client().

-spec get_status() -> {ok, map()} | {error, term()}.
get_status() ->
    hecate_mesh_client:get_status().

-spec is_connected() -> boolean().
is_connected() ->
    case hecate_mesh_client:get_client() of
        {ok, Pid} when is_pid(Pid) -> true;
        _ -> false
    end.

-spec discover_subscribers(binary()) -> {ok, list()} | {error, term()}.
discover_subscribers(Topic) ->
    hecate_mesh_client:discover_subscribers(Topic).
