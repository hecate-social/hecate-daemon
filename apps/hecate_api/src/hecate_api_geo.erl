%%% @doc API handler for geographic restriction endpoints
%%%
%%% Provides endpoints to check geo-restriction status, reload config,
%%% and check specific IP addresses.
-module(hecate_api_geo).

-export([init/2, routes/0]).

routes() ->
    [{"/api/geo/status", ?MODULE, [status]},
     {"/api/geo/reload", ?MODULE, [reload]},
     {"/api/geo/check/:ip", ?MODULE, [check_ip]}].

%% @doc Cowboy handler init - dispatch based on action
init(Req0, [status]) ->
    handle_status(Req0);
init(Req0, [reload]) ->
    handle_reload(Req0);
init(Req0, [check_ip]) ->
    handle_check_ip(Req0).

%% @private Handle GET /api/geo/status
handle_status(Req0) ->
    Status = geo_check:status(),
    LocalCheck = maps:get(local_check, Status, allowed),

    Response = #{
        <<"ok">> => true,
        <<"enabled">> => maps:get(enabled, Status, true),
        <<"database_loaded">> => maps:get(database_loaded, Status, false),
        <<"status">> => format_check_result(LocalCheck),
        <<"config">> => format_config(maps:get(config, Status, #{}))
    },

    Body = json:encode(Response),
    Req = cowboy_req:reply(200, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, []}.

%% @private Handle POST /api/geo/reload
handle_reload(Req0) ->
    Method = cowboy_req:method(Req0),
    case Method of
        <<"POST">> ->
            case geo_check:reload_config() of
                ok ->
                    Response = #{
                        <<"ok">> => true,
                        <<"message">> => <<"Configuration reloaded">>
                    },
                    Body = json:encode(Response),
                    Req = cowboy_req:reply(200, #{
                        <<"content-type">> => <<"application/json">>
                    }, Body, Req0),
                    {ok, Req, []};
                {error, Reason} ->
                    error_response(Req0, 500, io_lib:format("Reload failed: ~p", [Reason]))
            end;
        _ ->
            error_response(Req0, 405, <<"Method not allowed">>)
    end.

%% @private Handle GET /api/geo/check/:ip
handle_check_ip(Req0) ->
    IP = cowboy_req:binding(ip, Req0),
    case geo_check:check_ip(IP) of
        allowed ->
            Country = case geo_check:get_country(IP) of
                {ok, C} -> C;
                _ -> null
            end,
            Response = #{
                <<"ok">> => true,
                <<"ip">> => IP,
                <<"status">> => <<"allowed">>,
                <<"country">> => Country
            },
            Body = json:encode(Response),
            Req = cowboy_req:reply(200, #{
                <<"content-type">> => <<"application/json">>
            }, Body, Req0),
            {ok, Req, []};
        {blocked, CountryCode} ->
            Response = #{
                <<"ok">> => false,
                <<"ip">> => IP,
                <<"status">> => <<"blocked">>,
                <<"country">> => CountryCode,
                <<"message">> => <<"Service not available in this region">>
            },
            Body = json:encode(Response),
            Req = cowboy_req:reply(403, #{
                <<"content-type">> => <<"application/json">>
            }, Body, Req0),
            {ok, Req, []}
    end.

%% @private Format check result for JSON response
format_check_result(allowed) ->
    <<"allowed">>;
format_check_result({blocked, CountryCode}) ->
    #{<<"blocked">> => CountryCode}.

%% @private Format config for JSON response (hide sensitive data)
format_config(Config) ->
    #{
        <<"mode">> => maps:get(mode, Config, blocklist),
        <<"blocked_count">> => length(maps:get(blocked_countries, Config, [])),
        <<"allowed_count">> => length(maps:get(allowed_countries, Config, []))
    }.

%% @private Send error response
error_response(Req0, StatusCode, Message) when is_list(Message) ->
    error_response(Req0, StatusCode, list_to_binary(lists:flatten(Message)));
error_response(Req0, StatusCode, Message) when is_binary(Message) ->
    Response = #{
        <<"ok">> => false,
        <<"error">> => Message
    },
    Body = json:encode(Response),
    Req = cowboy_req:reply(StatusCode, #{
        <<"content-type">> => <<"application/json">>
    }, Body, Req0),
    {ok, Req, []}.
