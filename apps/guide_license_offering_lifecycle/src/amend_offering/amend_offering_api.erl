%%% @doc API handler: PATCH /api/appstore/offerings/:offering_id/amend
%%%
%%% Amends any optional fields on an offering.
%%% @end
-module(amend_offering_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings/:offering_id/amend", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"PATCH">> -> handle_patch(Req0, State);
        <<"PUT">> -> handle_patch(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_patch(Req0, _State) ->
    OfferingId = cowboy_req:binding(offering_id, Req0),
    case validate_offering_id(OfferingId) of
        ok -> read_body_and_amend(OfferingId, Req0);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req0)
    end.

validate_offering_id(undefined) -> {error, <<"offering_id is required">>};
validate_offering_id(OfferingId) when not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, <<"offering_id must be a non-empty string">>};
validate_offering_id(_) -> ok.

read_body_and_amend(OfferingId, Req0) ->
    case hecate_api_utils:read_json_body(Req0) of
        {ok, Params, Req1} ->
            CmdParams = Params#{<<"offering_id">> => OfferingId},
            do_amend(CmdParams, Req1);
        {error, invalid_json, Req1} ->
            hecate_api_utils:bad_request(<<"Invalid JSON body">>, Req1)
    end.

do_amend(Params, Req) ->
    case amend_offering_v1:from_map(Params) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_amend_offering:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(200, #{
                offering_id => amend_offering_v1:get_offering_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
