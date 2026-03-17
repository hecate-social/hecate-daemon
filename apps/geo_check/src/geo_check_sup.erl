%%% @doc geo_check top-level supervisor
%%%
%%% Starts locus GeoIP database loaders (City + ASN) and supervises
%%% the geo check worker.
-module(geo_check_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for locus calls (may not be in PLT)
-dialyzer({nowarn_function, [init/1, start_locus_loaders/1, start_locus_loader/2,
                             start_locus_from_file/2]}).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Databases = application:get_env(geo_check, databases, [
        {geo_city, {maxmind, "GeoLite2-City"}},
        {geo_asn, {maxmind, "GeoLite2-ASN"}}
    ]),
    start_locus_loaders(Databases),

    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },

    Children = [
        %% geo_check_config: loads and caches the restriction config
        {geo_check_config,
            {geo_check_config, start_link, []},
            permanent, 5000, worker, [geo_check_config]},

        %% geo_check_worker: periodic re-validation worker
        {geo_check_worker,
            {geo_check_worker, start_link, []},
            permanent, 5000, worker, [geo_check_worker]}
    ],

    logger:info("[geo_check] Supervisor started with ~p children", [length(Children)]),
    {ok, {SupFlags, Children}}.

%% @private Start all configured locus database loaders
start_locus_loaders([]) -> ok;
start_locus_loaders([{LoaderId, Source} | Rest]) ->
    case start_locus_loader(LoaderId, Source) of
        ok ->
            logger:info("[geo_check] Locus ~s loader started", [LoaderId]);
        {error, already_started} ->
            logger:info("[geo_check] Locus ~s loader already running", [LoaderId]);
        {error, Reason} ->
            logger:warning("[geo_check] Failed to start ~s loader: ~p", [LoaderId, Reason])
    end,
    start_locus_loaders(Rest).

%% @private Start a single locus loader
start_locus_loader(LoaderId, {maxmind, DbName}) ->
    case os:getenv("MAXMIND_LICENSE_KEY") of
        false ->
            logger:warning("[geo_check] MAXMIND_LICENSE_KEY not set - trying local file for ~s", [LoaderId]),
            start_locus_from_file(LoaderId, DbName);
        LicenseKey ->
            application:set_env(locus, license_key, LicenseKey),
            locus:start_loader(LoaderId, {maxmind, DbName})
    end;
start_locus_loader(LoaderId, {url, Url}) ->
    locus:start_loader(LoaderId, Url);
start_locus_loader(LoaderId, {file, Path}) ->
    locus:start_loader(LoaderId, {filesystem, Path}).

%% @private Try to load from local file if MaxMind key not available
start_locus_from_file(LoaderId, DbName) ->
    LocalPaths = [
        "priv/" ++ DbName ++ ".mmdb",
        "/usr/share/GeoIP/" ++ DbName ++ ".mmdb",
        "/var/lib/GeoIP/" ++ DbName ++ ".mmdb"
    ],
    case find_existing_file(LocalPaths) of
        {ok, Path} ->
            logger:info("[geo_check] Loading ~s from ~s", [LoaderId, Path]),
            locus:start_loader(LoaderId, {filesystem, Path});
        not_found ->
            logger:warning("[geo_check] No ~s database found", [DbName]),
            {error, no_database}
    end.

%% @private Find first existing file in list
find_existing_file([]) ->
    not_found;
find_existing_file([Path | Rest]) ->
    case filelib:is_regular(Path) of
        true -> {ok, Path};
        false -> find_existing_file(Rest)
    end.
