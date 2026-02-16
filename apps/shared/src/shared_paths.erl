%%% @doc Shared path utilities for all stores.
%%%
%%% Centralizes data directory resolution so all SQLite stores
%%% and ReckonDB stores write under ~/.hecate/ by default.
%%% Configurable via {hecate, [{data_dir, "/path"}]}.
-module(shared_paths).

-export([data_dir/0, db_path/1]).

%% @doc Returns the root data directory (default ~/.hecate/).
-spec data_dir() -> file:filename().
data_dir() ->
    case application:get_env(hecate, data_dir) of
        {ok, Dir} -> expand_path(Dir);
        undefined -> expand_path("~/.hecate")
    end.

%% @doc Returns the full path for a database file under data_dir().
-spec db_path(string() | binary()) -> file:filename().
db_path(Name) ->
    filename:join(data_dir(), Name).

%%% Internal

expand_path("~/" ++ Rest) ->
    filename:join(os:getenv("HOME"), Rest);
expand_path(Path) ->
    Path.
