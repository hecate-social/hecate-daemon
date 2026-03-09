%%% @doc API handler: POST /api/appstore/offerings/:offering_id/archive
%%%
%%% Archives an offering (walking skeleton).
%%% @end
-module(archive_offering_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings/:offering_id/archive", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_post(Req0, _State) ->
    OfferingId = cowboy_req:binding(offering_id, Req0),
    case validate(OfferingId) of
        ok -> do_archive(OfferingId, Req0);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req0)
    end.

validate(undefined) -> {error, <<"offering_id is required">>};
validate(OfferingId) when not is_binary(OfferingId); byte_size(OfferingId) =:= 0 ->
    {error, <<"offering_id must be a non-empty string">>};
validate(_) -> ok.

do_archive(OfferingId, Req) ->
    case archive_offering_v1:new(#{offering_id => OfferingId}) of
        {ok, Cmd} -> dispatch(Cmd, Req);
        {error, Reason} -> hecate_api_utils:bad_request(Reason, Req)
    end.

dispatch(Cmd, Req) ->
    case maybe_archive_offering:dispatch(Cmd) of
        {ok, Version, EventMaps} ->
            hecate_api_utils:json_ok(201, #{
                offering_id => archive_offering_v1:get_offering_id(Cmd),
                version => Version,
                events => EventMaps
            }, Req);
        {error, Reason} ->
            hecate_api_utils:bad_request(Reason, Req)
    end.
