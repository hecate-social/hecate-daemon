%%% @doc POST /api/mesh/publish — Agent-facing publish endpoint.
%%%
%%% Dispatches the `publish_mesh_fact_v1' command. The matching domain
%%% event is recorded in `mesh_publications_store'; the mesh emitter
%%% picks it up asynchronously and pushes the fact onto the Macula mesh
%%% via `hecate_mesh:publish/2'. This separation is non-negotiable per
%%% the mesh-integration doctrine.
%%%
%%% Request body:
%%%   #{<<"topic">>     => <<"agents.module_generated">>,
%%%     <<"fact">>      => #{...}}
%%%
%%% Response:
%%%   #{ok => true, topic => <<...>>, fact_id => <<...>>}
%%% @end
-module(publish_mesh_fact_api).

-export([init/2, routes/0]).

routes() -> [{"/api/mesh/publish", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    %% hecate_api_utils:read_json_body/1 is specced to return `{ok, map(), Req}'
    %% on success; non-object payloads (arrays, scalars) decode but blow up at
    %% the first get_field call. That matches every other handler in the codebase.
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Body, Req1} ->
            dispatch(Body, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"invalid JSON">>, Req1)
    end.

dispatch(Body, Req) ->
    Topic = hecate_api_utils:get_field(topic, Body),
    Fact  = hecate_api_utils:get_field(fact, Body),
    case validate(Topic, Fact) of
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req);
        ok ->
            RequestedAt = erlang:system_time(millisecond),
            Cmd = publish_mesh_fact_v1:new(Topic, Fact, RequestedAt),
            case maybe_publish_mesh_fact:dispatch(Cmd) of
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

validate(undefined, _) -> {error, <<"topic is required">>};
validate(_, undefined) -> {error, <<"fact is required">>};
validate(T, _) when not is_binary(T) -> {error, <<"topic must be a string">>};
validate(_, F) when not is_map(F) -> {error, <<"fact must be an object">>};
validate(_, _) -> ok.

%% @private Synthesise a stable fact id from the stream + version.
%% Real evoq event_ids are surfaced by the dispatcher in future when we
%% expose them up through the response; for now stream-version is the
%% audit anchor an agent can use.
fact_id(Version) ->
    Stream = mesh_publications_aggregate:stream_id(),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
