%%% @doc API handler: GET /api/appstore/licenses/:license_id
%%%
%%% Returns a single license by ID for the current consumer.
%%% @end
-module(get_license_by_id_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/licenses/:license_id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    LicenseId = cowboy_req:binding(license_id, Req0),
    case project_licenses_store:get_license(LicenseId) of
        {ok, License} ->
            hecate_api_utils:json_ok(License, Req0);
        {error, not_found} ->
            hecate_api_utils:json_error(404, <<"License not found">>, Req0)
    end.
