%%% @doc API handler for geographic restriction endpoints.
%%%
%%% Provides endpoints to check geo-restriction status, reload config,
%%% and check specific IP addresses.
%%% @end
-module(geo_check_api).

-export([init/2, routes/0]).

routes() ->
    [{"/api/geo/status", ?MODULE, [status]},
     {"/api/geo/reload", ?MODULE, [reload]},
     {"/api/geo/check/:ip", ?MODULE, [check_ip]}].

init(Req0, [status]) ->
    handle_status(Req0);
init(Req0, [reload]) ->
    handle_reload(Req0);
init(Req0, [check_ip]) ->
    handle_check_ip(Req0).

handle_status(Req0) ->
    Status = geo_check:status(),
    LocalCheck = maps:get(local_check, Status, allowed),
    hecate_api_utils:json_ok(#{
        enabled => maps:get(enabled, Status, true),
        database_loaded => maps:get(database_loaded, Status, false),
        status => format_check_result(LocalCheck),
        config => format_config(maps:get(config, Status, #{}))
    }, Req0).

handle_reload(Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            case geo_check:reload_config() of
                ok ->
                    hecate_api_utils:json_ok(#{message => <<"Configuration reloaded">>}, Req0);
                {error, Reason} ->
                    hecate_api_utils:json_error(500, Reason, Req0)
            end;
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

handle_check_ip(Req0) ->
    IP = cowboy_req:binding(ip, Req0),
    case geo_check:check_ip(IP) of
        allowed ->
            Country = case geo_check:get_country(IP) of
                {ok, C} -> C;
                _ -> null
            end,
            hecate_api_utils:json_ok(#{ip => IP, status => <<"allowed">>, country => Country}, Req0);
        {blocked, CountryCode} ->
            hecate_api_utils:json_response(403, #{
                ok => false,
                ip => IP,
                status => <<"blocked">>,
                country => CountryCode,
                message => <<"Service not available in this region">>
            }, Req0)
    end.

format_check_result(allowed) ->
    <<"allowed">>;
format_check_result({blocked, CountryCode}) ->
    #{<<"blocked">> => CountryCode}.

format_config(Config) ->
    #{
        mode => maps:get(mode, Config, blocklist),
        blocked_count => length(maps:get(blocked_countries, Config, [])),
        allowed_count => length(maps:get(allowed_countries, Config, []))
    }.
