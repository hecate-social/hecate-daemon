%%% @doc geo_check top-level supervisor
%%%
%%% Starts the locus GeoIP database loader and supervises the geo check worker.
-module(geo_check_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

%% Suppress dialyzer warnings for locus calls (may not be in PLT)
-dialyzer({nowarn_function, [init/1]}).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    %% Start locus GeoIP database loader
    DbSource = application:get_env(geo_check, db_source, {maxmind, "GeoLite2-Country"}),
    case start_locus_loader(DbSource) of
        ok ->
            logger:info("[geo_check] Locus GeoIP loader started");
        {error, already_started} ->
            logger:info("[geo_check] Locus GeoIP loader already running");
        {error, Reason} ->
            logger:warning("[geo_check] Failed to start locus loader: ~p (geo-check will allow all)", [Reason])
    end,

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

%% @private Start the locus database loader
start_locus_loader({maxmind, DbName}) ->
    %% Check for license key (required for MaxMind downloads)
    case os:getenv("MAXMIND_LICENSE_KEY") of
        false ->
            logger:warning("[geo_check] MAXMIND_LICENSE_KEY not set - trying local file"),
            start_locus_from_file();
        LicenseKey ->
            application:set_env(locus, license_key, LicenseKey),
            locus:start_loader(geo_db, {maxmind, DbName})
    end;
start_locus_loader({url, Url}) ->
    locus:start_loader(geo_db, Url);
start_locus_loader({file, Path}) ->
    locus:start_loader(geo_db, {filesystem, Path}).

%% @private Try to load from local file if MaxMind key not available
start_locus_from_file() ->
    LocalPaths = [
        "priv/GeoLite2-Country.mmdb",
        "/usr/share/GeoIP/GeoLite2-Country.mmdb",
        "/var/lib/GeoIP/GeoLite2-Country.mmdb"
    ],
    case find_existing_file(LocalPaths) of
        {ok, Path} ->
            logger:info("[geo_check] Loading GeoIP database from ~s", [Path]),
            locus:start_loader(geo_db, {filesystem, Path});
        not_found ->
            logger:warning("[geo_check] No GeoIP database found - geo-check will allow all"),
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
