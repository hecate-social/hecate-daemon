%%% @doc API handler: GET /api/appstore/offerings/:offering_id
%%%
%%% Returns details for a single offering entry enriched with
%%% consumer license and plugin install state, or 404 if not found.
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
    ConsumerId = cowboy_req:header(<<"x-hecate-user-id">>, Req0, undefined),
    case project_license_offerings_store:get_offering(OfferingId) of
        {ok, Entry} ->
            Enriched = enrich(Entry, ConsumerId),
            hecate_api_utils:json_ok(#{plugin => Enriched}, Req0);
        {error, not_found} ->
            hecate_api_utils:not_found(Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

%% --- Enrichment (same logic as browse_offerings_api) ---

enrich(Item, ConsumerId) ->
    PluginId = maps:get(plugin_id, Item, undefined),
    WithLicense = enrich_license(Item, PluginId, ConsumerId),
    enrich_plugin(WithLicense, PluginId).

enrich_license(Item, _PluginId, undefined) ->
    Item#{license_id => undefined, installed => undefined, installed_version => undefined};
enrich_license(Item, PluginId, ConsumerId) ->
    case project_licenses_store:get_license_for_plugin(PluginId, ConsumerId) of
        {ok, License} ->
            Item#{
                license_id        => maps:get(license_id, License, undefined),
                installed         => maps:get(installed, License, undefined),
                installed_version => maps:get(installed_version, License, undefined)
            };
        {error, not_found} ->
            Item#{license_id => undefined, installed => undefined, installed_version => undefined}
    end.

enrich_plugin(Item, PluginId) ->
    case project_plugins_store:get(PluginId) of
        {ok, Plugin} ->
            Item#{
                available_actions => maps:get(available_actions, Plugin, []),
                status_label      => maps:get(status_label, Plugin, undefined),
                installed_version => maps:get(installed_version, Plugin, maps:get(installed_version, Item, undefined))
            };
        {error, not_found} ->
            Item
    end.
