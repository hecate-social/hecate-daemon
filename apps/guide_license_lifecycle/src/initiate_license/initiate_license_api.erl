%%% @doc API handler: POST /api/appstore/licenses/initiate
%%%
%%% Initiates a consumer license (lightweight birth).
%%% Requires consumer_id, plugin_id, offering_id.
%%% @end
-module(initiate_license_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/initiate", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            do_initiate_license(Params, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
    end.

do_initiate_license(Params, Req) ->
    ConsumerId = hecate_api_utils:get_field(consumer_id, Params),
    PluginId = hecate_api_utils:get_field(plugin_id, Params),
    OfferingId = hecate_api_utils:get_field(offering_id, Params),
    case validate(ConsumerId, PluginId, OfferingId) of
        ok -> create(ConsumerId, PluginId, OfferingId, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

validate(undefined, _, _) -> {error, <<"consumer_id is required">>};
validate(V, _, _) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, <<"consumer_id must be a non-empty string">>};
validate(_, undefined, _) -> {error, <<"plugin_id is required">>};
validate(_, V, _) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, <<"plugin_id must be a non-empty string">>};
validate(_, _, undefined) -> {error, <<"offering_id is required">>};
validate(_, _, V) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, <<"offering_id must be a non-empty string">>};
validate(_, _, _) -> ok.

create(ConsumerId, PluginId, OfferingId, Req) ->
    CmdParams = #{
        consumer_id => ConsumerId,
        plugin_id => PluginId,
        offering_id => OfferingId
    },
    case initiate_license_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_initiate_license:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                license_id => initiate_license_v1:get_license_id(Cmd),
                consumer_id => initiate_license_v1:get_consumer_id(Cmd),
                plugin_id => initiate_license_v1:get_plugin_id(Cmd),
                offering_id => initiate_license_v1:get_offering_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
