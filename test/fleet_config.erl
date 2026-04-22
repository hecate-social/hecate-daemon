%%% @doc Fleet test configuration.
%%%
%%% Reads `HECATE_FLEET_CONFIG` env var → path to a config file
%%% (defaults to `test/fleet/fleet.config`). The config is a single
%%% Erlang term map describing each daemon node + the realm server.
%%%
%%% Shape:
%%% ```
%%% #{
%%%   admin_token => <<"...">>,        %% same value as the daemons' HECATE_ADMIN_TOKEN
%%%   realm => <<"io.macula">>,        %% target realm
%%%   daemons => [
%%%       #{role => alice, ssh => <<"rl@beam00.lab">>,
%%%         socket => <<"~/.hecate/hecate-daemon/sockets/api.sock">>,
%%%         api_url => <<"http://127.0.0.1:4444">>,
%%%         did => <<"mri:agent:io.macula/alice">>},
%%%       ...
%%%   ],
%%%   realm_server => #{
%%%       admin_url => <<"https://realm.macula.io/admin">>,
%%%       admin_token => <<"...">>
%%%   }
%%% }
%%% ```
%%%
%%% If the config file isn't present, `load/0` returns `{error,
%%% no_config}` so the CT suite can `init_per_suite` with
%%% `{skip, "fleet config not provided — set HECATE_FLEET_CONFIG"}`.
%%% This keeps the suite green in CI while still being runnable for
%%% operators with the right setup.
%%% @end
-module(fleet_config).

-export([load/0, load/1, daemon/2, realm_server/1, realm/1, admin_token/1]).

-spec load() -> {ok, map()} | {error, no_config}.
load() ->
    Path = case os:getenv("HECATE_FLEET_CONFIG") of
        false -> default_config_path();
        Set   -> Set
    end,
    load(Path).

default_config_path() ->
    case code:priv_dir(hecate) of
        {error, _} -> "test/fleet/fleet.config";
        PrivDir    -> filename:join(PrivDir, "fleet.config")
    end.

-spec load(string()) -> {ok, map()} | {error, no_config}.
load(Path) ->
    case file:consult(Path) of
        {ok, [Config]} when is_map(Config) -> {ok, Config};
        {ok, _Other}                       -> {error, bad_config_shape};
        {error, enoent}                    -> {error, no_config};
        {error, _} = E                      -> E
    end.

%% @doc Look up a daemon by role atom (alice, bob, carol, dave).
-spec daemon(map(), atom()) -> {ok, map()} | {error, not_found}.
daemon(Config, Role) when is_atom(Role) ->
    Daemons = maps:get(daemons, Config, []),
    case lists:filter(
            fun(D) -> maps:get(role, D, undefined) =:= Role end,
            Daemons) of
        [D | _] -> {ok, D};
        []      -> {error, not_found}
    end.

-spec realm_server(map()) -> {ok, map()} | {error, not_found}.
realm_server(Config) ->
    case maps:get(realm_server, Config, undefined) of
        undefined -> {error, not_found};
        Map       -> {ok, Map}
    end.

realm(Config) -> maps:get(realm, Config, <<"io.macula">>).
admin_token(Config) -> maps:get(admin_token, Config, undefined).

