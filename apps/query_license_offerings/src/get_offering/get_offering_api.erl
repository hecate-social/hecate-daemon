%%% @doc API handler: GET /api/appstore/offerings/:offering_id
%%%
%%% Returns details for a single offering entry, or 404 if not found.
%%% @end
-module(get_offering_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings/:offering_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    OfferingId = cowboy_req:binding(offering_id, Req0),
    case project_license_offerings_store:get_offering(OfferingId) of
        {ok, Entry} ->
            hecate_api_utils:json_ok(Entry, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.
