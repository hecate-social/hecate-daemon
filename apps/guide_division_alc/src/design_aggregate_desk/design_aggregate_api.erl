%%% @doc API handler: POST /api/divisions/:division_id/design/aggregates
-module(design_aggregate_api).

-export([init/2, routes/0]).

routes() -> [{"/api/divisions/:division_id/design/aggregates", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    DivisionId = cowboy_req:binding(division_id, Req0),
    case DivisionId of
        undefined ->
            hecate_api_utils:bad_request(<<"division_id is required">>, Req0);
        _ ->
            case hecate_api_utils:read_json_body(Req0) of
                {ok, Params, Req1} ->
                    do_design_aggregate(DivisionId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_design_aggregate(DivisionId, Params, Req) ->
    AggregateName = hecate_api_utils:get_field(aggregate_name, Params),
    Description = hecate_api_utils:get_field(description, Params),
    StreamPrefix = hecate_api_utils:get_field(stream_prefix, Params),
    Fields = hecate_api_utils:get_field(fields, Params),

    CmdParams = #{
        division_id => DivisionId,
        aggregate_name => AggregateName,
        description => Description,
        stream_prefix => StreamPrefix,
        fields => Fields
    },
    case design_aggregate_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_design_aggregate:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                division_id => design_aggregate_v1:get_division_id(Cmd),
                aggregate_name => design_aggregate_v1:get_aggregate_name(Cmd),
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
