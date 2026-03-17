%%% @doc API handler: GET /api/appstore/offerings
%%%
%%% Returns the full offerings catalog enriched with consumer-facing
%%% license and plugin install state from the local node.
%%%
%%% Enrichment fields added per item:
%%%   - license_id, installed, installed_version (from licenses read model)
%%%   - available_actions, status_label (from plugins read model)
%%% @end
-module(browse_offerings_api).

-export([init/2, routes/0]).

routes() -> [{"/api/appstore/offerings", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    ConsumerId = cowboy_req:header(<<"x-hecate-user-id">>, Req0, undefined),
    case project_license_offerings_store:browse_offerings() of
        {ok, Items} ->
            Enriched = [enrich(Item, ConsumerId) || Item <- Items],
            hecate_api_utils:json_ok(#{items => Enriched}, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

%% --- Enrichment ---

enrich(Item, ConsumerId) ->
    PluginId = maps:get(plugin_id, Item, undefined),
    WithLicense = enrich_license(Item, PluginId, ConsumerId),
    enrich_plugin(WithLicense, PluginId).

%% Add license_id and installed flag from the consumer's license.
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

%% Override available_actions and status_label with plugin install state.
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
