%%% @doc API handler: POST /api/divisions/:division_id/design/events
-module(design_event_api).

-export([init/2]).

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
                    do_design_event(DivisionId, Params, Req1);
                {error, invalid_json, Req1} ->
                    hecate_api_utils:bad_request(<<"Invalid JSON">>, Req1)
            end
    end.

do_design_event(DivisionId, Params, Req) ->
    EventName = hecate_api_utils:get_field(event_name, Params),
    Description = hecate_api_utils:get_field(description, Params),
    AggregateName = hecate_api_utils:get_field(aggregate_name, Params),
    Fields = hecate_api_utils:get_field(fields, Params),

    CmdParams = #{
        division_id => DivisionId,
        event_name => EventName,
        description => Description,
        aggregate_name => AggregateName,
        fields => Fields
    },
    case design_event_v1:new(CmdParams) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_design_event:dispatch(Cmd) of
        {ok, _Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                division_id => design_event_v1:get_division_id(Cmd),
                event_name => design_event_v1:get_event_name(Cmd),
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
