%%% @doc Cowboy middleware for route scoping per connector.
%%%
%%% Checks request path against the connector's allowed_routes list.
%%% If the route is not in scope, returns 403 Forbidden.
%%% When allowed_routes is 'all', this middleware is not added to the chain.
-module(connector_scope_middleware).
-behaviour(cowboy_middleware).

-export([execute/2]).

-spec execute(cowboy_req:req(), cowboy:opts()) ->
    {ok, cowboy_req:req(), cowboy:opts()} | {stop, cowboy_req:req()}.
execute(Req, Env) ->
    AllowedRoutes = maps:get(allowed_routes, Env, all),
    case AllowedRoutes of
        all ->
            {ok, Req, Env};
        Routes when is_list(Routes) ->
            Path = cowboy_req:path(Req),
            case is_route_allowed(Path, Routes) of
                true ->
                    {ok, Req, Env};
                false ->
                    Resp = json:encode(#{
                        ok => false,
                        error => <<"route_not_allowed">>
                    }),
                    Req2 = cowboy_req:reply(403,
                        #{<<"content-type">> => <<"application/json">>},
                        Resp,
                        Req
                    ),
                    {stop, Req2}
            end
    end.

%% @private Check if a request path matches any of the allowed route prefixes.
is_route_allowed(_Path, []) ->
    false;
is_route_allowed(Path, [Prefix | Rest]) ->
    PrefixSize = byte_size(Prefix),
    case Path of
        <<Prefix:PrefixSize/binary, _/binary>> ->
            true;
        _ ->
            is_route_allowed(Path, Rest)
    end.
