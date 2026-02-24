%%% @doc Auto-discovery route aggregator for hecate API.
%%%
%%% Each API handler owns its route by exporting routes/0.
%%% This module discovers all such handlers across hecate apps
%%% and compiles them into a Cowboy dispatch table.
%%% @end
-module(hecate_api_routes).

-export([compile/0]).

%% All hecate OTP apps that may contain API handlers.
-define(HECATE_APPS, [
    hecate_api,
    guide_settings_lifecycle, query_settings,
    guide_venture_lifecycle, query_venture_lifecycle,
    guide_division_alc, query_division_alc,
    guide_node_lifecycle, query_node_lifecycle,
    mentor_llms, query_mentorships,
    serve_llm,
    manage_irc, query_irc,
    run_snake_duel, query_snake_duel,
    breed_snake_gladiators, query_snake_gladiators
]).

-spec compile() -> cowboy_router:dispatch_rules().
compile() ->
    cowboy_router:compile([{'_', discover_routes()}]).

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
