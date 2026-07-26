%%% @doc DELETE /api/mesh/subscriptions/:topic — Agent-facing unsubscribe.
%%%
%%% Dispatches the `remove_mesh_subscription_v1' command. The matching
%%% domain event is recorded in `mesh_subscriptions_store'; the mesh
%%% emitter (forthcoming slice) picks it up asynchronously and calls
%%% `hecate_mesh:unsubscribe/1' on the stored subscription reference.
%%%
%%% Idempotent: removing a topic the daemon isn't subscribed to returns
%%% the existing stream version (no new event recorded).
%%%
%%% Path binding `:topic' is URL-encoded; cowboy decodes once.
%%%
%%% Response:
%%%   #{ok => true, topic => <<...>>, fact_id => <<...>>}
%%% @end
-module(remove_mesh_subscription_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/subscriptions/:topic", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"DELETE">> -> handle_delete(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_delete(Req0, _State) ->
    Topic = cowboy_req:binding(topic, Req0),
    case validate(Topic) of
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req0);
        ok ->
            RequestedAt = erlang:system_time(millisecond),
            Cmd = remove_mesh_subscription_v1:new(Topic, RequestedAt),
            case maybe_remove_mesh_subscription:dispatch(Cmd) of
                {ok, Version, _Events} ->
                    hecate_api_utils:json_ok(#{
                        topic        => Topic,
                        requested_at => RequestedAt,
                        fact_id      => fact_id(Version)
                    }, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(502, Reason, Req0)
            end
    end.

validate(undefined)                  -> {error, <<"topic is required">>};
validate(T) when not is_binary(T)    -> {error, <<"topic must be a string">>};
validate(<<>>)                       -> {error, <<"topic must not be empty">>};
validate(_)                          -> ok.

fact_id(Version) ->
    Stream = mesh_subscriptions_aggregate:stream_id(),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
