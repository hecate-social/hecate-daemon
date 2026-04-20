%%% @doc Auto-discovery route aggregator for hecate API.
%%%
%%% Each API handler owns its route by exporting routes/0.
%%% This module discovers all such handlers across hecate apps
%%% and compiles them into a Cowboy dispatch table.
%%% @end
-module(hecate_api_routes).

-export([compile/0, discover_routes/0]).

%% All hecate OTP apps that may contain API handlers.
%% Martha apps moved to hecate-app-martha plugin (routes discovered dynamically).
-define(HECATE_APPS, [
    hecate_api,
    geo_check,
    hecate_mesh,
    guide_settings_lifecycle, query_settings,
    guide_realm_memberships, query_realm_memberships,
    guide_site_lifecycle, query_site,
    discover_lan,
    serve_llm,
    guide_license_offering_lifecycle, project_license_offerings, query_license_offerings,
    guide_license_lifecycle, project_licenses, query_licenses,
    guide_procurement_lifecycle, project_procurements, query_procurements,
    guide_sale_lifecycle, project_sales, query_sales,
    guide_payment_lifecycle, project_payments, query_payments,
    guide_plugin_lifecycle, project_plugins, query_plugins,
    guide_launcher_lifecycle, project_launcher, query_launcher,
    guide_mpong_game_lifecycle, project_mpong_games, query_mpong_games,
    guide_briefcase_lifecycle, project_briefcase_files, query_briefcase_files,
    query_observer
]).

-spec compile() -> cowboy_router:dispatch_rules().
compile() ->
    ApiRoutes = discover_routes(),
    StaticRoutes = hecate_api_static:routes(),
    PluginApiRoutes = plugin_api_routes(),
    PluginStaticRoutes = plugin_static_routes(),
    %% SPA fallback MUST be last — catches all unmatched paths
    SpaFallback = [{'_', hecate_api_spa_fallback, []}],
    cowboy_router:compile([{'_', ApiRoutes ++ PluginApiRoutes
                                 ++ StaticRoutes ++ PluginStaticRoutes
                                 ++ SpaFallback}]).

plugin_api_routes() ->
    try hecate_plugin_loader:plugin_routes()
    catch Class:Reason ->
        logger:warning("[hecate_api_routes] Plugin routes failed: ~p:~p", [Class, Reason]),
        []
    end.

plugin_static_routes() ->
    try hecate_plugin_loader:plugin_static_routes()
    catch Class:Reason ->
        logger:warning("[hecate_api_routes] Plugin static routes failed: ~p:~p", [Class, Reason]),
        []
    end.

-spec discover_routes() -> [cowboy_router:route_match()].
discover_routes() ->
    lists:flatmap(fun collect_app_routes/1, ?HECATE_APPS).

collect_app_routes(App) ->
    Mods = app_modules(App),
    Handlers = [M || M <- Mods, M =/= ?MODULE, exports_routes(M)],
    lists:flatmap(fun(M) -> M:routes() end, Handlers).

app_modules(App) ->
    case application:get_key(App, modules) of
        {ok, Mods} -> Mods;
        _ -> []
    end.

exports_routes(Mod) ->
    code:ensure_loaded(Mod),
    erlang:function_exported(Mod, routes, 0).
