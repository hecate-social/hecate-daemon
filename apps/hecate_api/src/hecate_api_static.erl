%%%-------------------------------------------------------------------
%%% @doc Static file handler for the daemon-served UI.
%%%
%%% Serves the SvelteKit static build from priv/static/.
%%% SPA fallback: any path not matching a file returns index.html.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_api_static).

-export([routes/0]).

routes() ->
    case static_dir() of
        {ok, Dir} ->
            [
                %% Versioned assets (long cache)
                {"/_app/[...]", cowboy_static, {dir, filename:join(Dir, "_app"),
                    [{mimetypes, cow_mimetypes, all}]}},
                %% Static files (favicon, images, etc.)
                {"/favicon.png", cowboy_static, {file, filename:join(Dir, "favicon.png")}},
                {"/logo.svg", cowboy_static, {file, filename:join(Dir, "logo.svg")}},
                {"/robots.txt", cowboy_static, {file, filename:join(Dir, "robots.txt")}},
                {"/knowing-goddess.jpg", cowboy_static, {file, filename:join(Dir, "knowing-goddess.jpg")}},
                {"/artwork/[...]", cowboy_static, {dir, filename:join(Dir, "artwork"),
                    [{mimetypes, cow_mimetypes, all}]}}
            ];
        error ->
            logger:warning("[hecate_api_static] priv/static not found — UI not available"),
            []
    end.

static_dir() ->
    case code:priv_dir(hecate) of
        {error, _} -> error;
        PrivDir ->
            Dir = filename:join(PrivDir, "static"),
            case filelib:is_dir(Dir) of
                true -> {ok, Dir};
                false -> error
            end
    end.
