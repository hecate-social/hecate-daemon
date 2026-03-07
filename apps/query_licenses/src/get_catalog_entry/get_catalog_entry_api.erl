%%% @doc API handler: GET /api/appstore/catalog/:id
%%%
%%% Returns details for a single catalog entry, including license
%%% and install status for the current user.
%%% @end
-module(get_catalog_entry_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/catalog/:id", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    case cowboy_req:header(<<"x-hecate-user-id">>, Req0) of
        undefined ->
            hecate_api_utils:json_error(401, <<"Missing X-Hecate-User-Id header">>, Req0);
        UserId ->
            PluginId = cowboy_req:binding(id, Req0),
            case project_licenses_store:get_catalog_entry(PluginId) of
                {ok, Entry} ->
                    License = fetch_license(PluginId, UserId),
                    Result = Entry#{license => License},
                    hecate_api_utils:json_ok(#{plugin => Result}, Req0);
                {error, not_found} ->
                    hecate_api_utils:not_found(Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end
    end.

fetch_license(PluginId, UserId) ->
    case project_licenses_store:get_license_for_plugin(PluginId, UserId) of
        {ok, License} -> License;
        {error, not_found} -> null
    end.
