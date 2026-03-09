%%%-------------------------------------------------------------------
%%% @doc SPA fallback handler.
%%%
%%% Serves index.html for any path not matched by API or static routes.
%%% This is needed for SvelteKit client-side routing — paths like
%%% /settings, /llm, /appstore are handled by the JS router.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_spa_fallback).

-export([init/2]).

init(Req0, State) ->
    case code:priv_dir(hecate) of
        {error, _} ->
            Req = cowboy_req:reply(503, #{}, <<"UI not available">>, Req0),
            {ok, Req, State};
        PrivDir ->
            IndexPath = filename:join([PrivDir, "static", "index.html"]),
            case file:read_file(IndexPath) of
                {ok, Body} ->
                    Req = cowboy_req:reply(200,
                        #{<<"content-type">> => <<"text/html; charset=utf-8">>},
                        Body, Req0),
                    {ok, Req, State};
                {error, _} ->
                    Req = cowboy_req:reply(404, #{}, <<"Not Found">>, Req0),
                    {ok, Req, State}
            end
    end.
