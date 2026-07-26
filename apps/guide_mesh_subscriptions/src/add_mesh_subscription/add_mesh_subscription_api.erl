%%% @doc POST /api/mesh/subscriptions — Agent-facing subscribe endpoint.
%%%
%%% Dispatches the `add_mesh_subscription_v1' command. The matching
%%% domain event is recorded in `mesh_subscriptions_store'; the mesh
%%% emitter (forthcoming slice) picks it up asynchronously and calls
%%% `hecate_mesh:subscribe/2' with the inbound LISTENER callback. This
%%% separation is non-negotiable per the mesh-integration doctrine.
%%%
%%% Idempotent: re-subscribing to an existing topic returns the
%%% existing stream version (no new event recorded).
%%%
%%% Request body:
%%%   #{<<"topic">> => <<"chat.demo">>}
%%%
%%% Response:
%%%   #{ok => true, topic => <<...>>, fact_id => <<...>>}
%%% @end
-module(add_mesh_subscription_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/subscriptions", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            dispatch(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"invalid JSON">>, Req1)
    end.

dispatch(Body, Req) ->
    Topic = hecate_api_utils:get_field(topic, Body),
    case validate(Topic) of
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req);
        ok ->
            RequestedAt = erlang:system_time(millisecond),
            Cmd = add_mesh_subscription_v1:new(Topic, RequestedAt),
            case maybe_add_mesh_subscription:dispatch(Cmd) of
                {ok, Version, _Events} ->
                    hecate_api_utils:json_ok(#{
                        topic        => Topic,
                        requested_at => RequestedAt,
                        fact_id      => fact_id(Version)
                    }, Req);
                {error, Reason} ->
                    hecate_api_utils:json_error(502, Reason, Req)
            end
    end.

validate(undefined)                  -> {error, <<"topic is required">>};
validate(T) when not is_binary(T)    -> {error, <<"topic must be a string">>};
validate(<<>>)                       -> {error, <<"topic must not be empty">>};
validate(_)                          -> ok.

%% @private Synthesise a stable fact id from the stream + version.
fact_id(Version) ->
    Stream = mesh_subscriptions_aggregate:stream_id(),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
