%%% @doc API handler: POST /api/appstore/offerings/:offering_id/announce
%%%
%%% Announces an offering (pre-publish step).
%%% @end
-module(announce_offering_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings/:offering_id/announce", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    OfferingId = cowboy_req:binding(offering_id, Req0),
    case validate(OfferingId) of
        ok -> do_announce(OfferingId, Req0);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req0)
    end.

validate(undefined) -> {error, <<"offering_id is required">>};
validate(OfferingId) when not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, <<"offering_id must be a non-empty string">>};
validate(_) -> ok.

do_announce(OfferingId, Req) ->
    case announce_offering_v1:new(#{offering_id => OfferingId}) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_announce_offering:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                offering_id => announce_offering_v1:get_offering_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
