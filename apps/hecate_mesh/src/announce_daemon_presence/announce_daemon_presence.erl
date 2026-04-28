%%% @doc Daemon presence announcer.
%%%
%%% Mirrors `hecate_station_announcer' in daemon space — periodically
%%% publishes a signed `node_record' (`type=0x01') tagged with
%%% `kind=daemon' into the relay-mesh DHT via the per-relay
%%% `macula_station_link' pool. Records are refreshed before TTL
%%% expires (default: refresh at 75% of TTL). On graceful shutdown
%%% the announcer publishes a signed tombstone so subscribers learn
%%% the daemon is gone without waiting for TTL.
%%%
%%% == Why a daemon needs to announce ==
%%%
%%% Realm dashboards subscribe to `_mesh.daemon.announced_v1' on
%%% every connected station. The station-side fact publisher fans
%%% out an EVENT frame on that topic whenever a `node_record' with
%%% `kind=daemon' lands in any of its identity DHTs. Without this
%%% gen_server the daemon is invisible to any realm-side topology
%%% view.
%%%
%%% == Activation ==
%%%
%%% Started under `hecate_mesh_sup'. The `put_record' call returns
%%% `{error, not_activated}' before mesh activation; the announcer
%%% logs at debug level and retries on the next tick. Once mesh
%%% activates the next refresh hits the wire.
%%%
%%% == What lives in the record ==
%%%
%%% * `node_id'      — the daemon's signing pubkey
%%% * `realms'       — empty list (daemon is realm-agnostic at this
%%%                    layer; realm membership lives in the dedicated
%%%                    `realm_member_identity_v1' record type 0x20)
%%% * `capabilities' — bit field, currently 0 (placeholder)
%%% * `kind'         — literal binary `<<"daemon">>'
%%% * `hostname'     — the daemon's host name (best-effort, optional)
%%% @end
-module(announce_daemon_presence).
-behaviour(gen_server).

-export([start_link/0, stop/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(DEFAULT_TTL_MS,           600_000).        %% 10 min
-define(DEFAULT_REFRESH_FRACTION, 0.75).           %% refresh at 75% of TTL
-define(NOT_ACTIVATED_BACKOFF_MS, 30_000).         %% retry every 30s
                                                   %% while mesh dormant

-record(state, {
    ttl_ms         :: pos_integer(),
    refresh_ms     :: pos_integer(),
    timer_ref      :: reference() | undefined,
    %% Self-geolocation. Resolved lazily on first publish via the
    %% geo_check library (public-IP discovery → MaxMind GeoIP DB).
    %% Cached for the daemon's lifetime — daemons don't move. Empty
    %% map until resolved; merged into the announce opts so the realm
    %% topology can render daemons by city/country/lat/lng.
    geo            :: map() | undefined
}).

%%====================================================================
%% Public API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec stop(pid()) -> ok.
stop(Pid) ->
    gen_server:stop(Pid, shutdown, 5_000).

%%====================================================================
%% gen_server
%%====================================================================

init([]) ->
    process_flag(trap_exit, true),
    Ttl       = ?DEFAULT_TTL_MS,
    RefreshMs = round(Ttl * ?DEFAULT_REFRESH_FRACTION),
    %% Fire once on init so daemons appear in the realm topology
    %% as soon as mesh activates, not after the first 7.5 min tick.
    self() ! {refresh, undefined},
    {ok, #state{ttl_ms = Ttl, refresh_ms = RefreshMs, geo = undefined}}.

handle_call(_Msg, _From, S) ->
    {reply, {error, unknown_call}, S}.

handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info({refresh, _OldRef}, #state{ttl_ms = Ttl} = S) ->
    S1   = ensure_geo(S),
    Next = on_refresh_result(publish_node_record(Ttl, geo_or_empty(S1)), S1),
    {noreply, schedule(Next, S1)};
handle_info(_, S) ->
    {noreply, S}.

terminate(Reason, _S) ->
    publish_tombstone_if_graceful(Reason).

code_change(_OldVsn, S, _Extra) ->
    {ok, S}.

%%====================================================================
%% Refresh loop
%%====================================================================

%% Publish path returns one of:
%%   `ok'                           — success; sleep for `refresh_ms'
%%   `{error, not_activated}'       — mesh dormant; back off briefly
%%   `{error, no_station_connected}'— activated but no relays up;
%%                                    same backoff
%%   `{error, _Other}'              — log + sleep `refresh_ms' anyway
publish_node_record(TtlMs, Geo) ->
    %% hecate_identity may not be up yet when we boot — both apps
    %% are children of the daemon's top-level sup and there is no
    %% start-order guarantee across siblings. `gen_server:call/2'
    %% on a non-existent server raises `exit({noproc, _})'; catch
    %% it and surface as `{error, no_identity}' so the announcer's
    %% backoff loop applies.
    try hecate_identity:signing_keypair() of
        {ok, KeyPair} ->
            do_publish(KeyPair, TtlMs, Geo);
        not_initialized ->
            logger:debug("[announce_daemon_presence] identity not initialised"),
            {error, no_identity}
    catch
        exit:{noproc, _} ->
            logger:debug("[announce_daemon_presence] hecate_identity not running"),
            {error, no_identity}
    end.

do_publish(KeyPair, TtlMs, Geo) ->
    Pub      = macula_identity:public(KeyPair),
    Hostname = node_hostname(),
    Base     = #{ttl_ms   => TtlMs,
                 kind     => <<"daemon">>,
                 hostname => Hostname},
    %% `Geo' is the cached geo_check result (city/country/lat/lng or
    %% empty). Merge into opts so the realm topology can render the
    %% daemon at its physical location. macula_record:node_record/4
    %% silently ignores unknown keys, so an empty `Geo' is safe.
    Opts     = maps:merge(Base, Geo),
    Unsigned = macula_record:node_record(Pub, [], 0, Opts),
    Signed   = macula_record:sign(Unsigned, KeyPair),
    hecate_mesh:put_record(Signed).

on_refresh_result(ok, _S) ->
    refresh;
on_refresh_result({error, not_activated}, _S) ->
    backoff;
on_refresh_result({error, no_station_connected}, _S) ->
    backoff;
on_refresh_result({error, no_identity}, _S) ->
    backoff;
on_refresh_result({error, Reason}, _S) ->
    logger:warning(
      "[announce_daemon_presence] put_record failed: ~p — retrying",
      [Reason]),
    refresh.

schedule(refresh, #state{refresh_ms = Ms} = S) ->
    schedule_after(Ms, S);
schedule(backoff, S) ->
    schedule_after(?NOT_ACTIVATED_BACKOFF_MS, S).

schedule_after(Ms, S) ->
    Ref = make_ref(),
    erlang:send_after(Ms, self(), {refresh, Ref}),
    S#state{timer_ref = Ref}.

%%====================================================================
%% Tombstone on graceful shutdown
%%====================================================================

publish_tombstone_if_graceful(shutdown)        -> publish_tombstone(shutdown);
publish_tombstone_if_graceful({shutdown, _})   -> publish_tombstone(shutdown);
publish_tombstone_if_graceful(normal)          -> publish_tombstone(normal);
publish_tombstone_if_graceful(_)               -> ok.

publish_tombstone(Reason) ->
    case hecate_identity:signing_keypair() of
        {ok, KeyPair} ->
            do_publish_tombstone(KeyPair, Reason);
        not_initialized ->
            ok
    end.

do_publish_tombstone(KeyPair, Reason) ->
    Pub      = macula_identity:public(KeyPair),
    %% type 0x01 = node_record. Tombstone for the daemon's own
    %% presence record.
    Unsigned = macula_record:tombstone(Pub, _NodeRecordType = 16#01,
                                        Reason),
    Signed   = macula_record:sign(Unsigned, KeyPair),
    _ = catch hecate_mesh:put_record(Signed),
    ok.

%%====================================================================
%% Helpers
%%====================================================================

%% Resolve self-geolocation lazily. The first refresh tick fires
%% before mesh is activated, but we attempt the lookup on every tick
%% until it succeeds — hackney + locus are both up by the time the
%% daemon's `hecate_mesh' app boots, so a typical first attempt
%% succeeds within seconds. Cached in state for the daemon's lifetime
%% (daemons don't move).
ensure_geo(#state{geo = undefined} = S) ->
    case discover_geo() of
        {ok, Geo} ->
            logger:info("[announce_daemon_presence] resolved self-geo: ~p", [Geo]),
            S#state{geo = Geo};
        {error, Reason} ->
            logger:debug(
              "[announce_daemon_presence] geo lookup deferred: ~p", [Reason]),
            S
    end;
ensure_geo(S) ->
    S.

geo_or_empty(#state{geo = undefined}) -> #{};
geo_or_empty(#state{geo = G})         -> G.

%% Geo discovery prefers explicit env vars over the GeoIP DB lookup.
%% Operators set HECATE_GEO_LAT/LNG/CITY/COUNTRY on each beam node
%% (different per node so daemons don't stack into a single marker
%% on the realm map). Falls back to geo_check (locus + MaxMind
%% GeoLite2-City) when env vars aren't set — locus may not have a
%% DB available in every container.
discover_geo() ->
    case env_geo() of
        {ok, Geo} -> {ok, Geo};
        error     -> on_public_ip(geo_check:get_public_ip())
    end.

env_geo() ->
    Lat = env_float("HECATE_GEO_LAT"),
    Lng = env_float("HECATE_GEO_LNG"),
    City    = env_binary("HECATE_GEO_CITY"),
    Country = env_binary("HECATE_GEO_COUNTRY"),
    on_env_geo(Lat, Lng, City, Country).

on_env_geo({ok, Lat}, {ok, Lng}, City, Country)
  when is_float(Lat); is_integer(Lat) ->
    {ok, drop_undefined(#{lat     => Lat,
                          lng     => Lng,
                          city    => unwrap_optional(City),
                          country => unwrap_optional(Country)})};
on_env_geo(_, _, _, _) ->
    error.

env_float(Var) ->
    case os:getenv(Var) of
        false -> error;
        ""    -> error;
        S     -> parse_number(S)
    end.

parse_number(S) ->
    case string:to_float(S) of
        {F, []} -> {ok, F};
        _       ->
            case string:to_integer(S) of
                {I, []} -> {ok, float(I)};
                _       -> error
            end
    end.

env_binary(Var) ->
    case os:getenv(Var) of
        false -> error;
        ""    -> error;
        S     -> {ok, list_to_binary(S)}
    end.

unwrap_optional({ok, V}) -> V;
unwrap_optional(error)   -> undefined.

drop_undefined(M) ->
    maps:filter(fun(_K, V) -> V =/= undefined andalso V =/= null end, M).

on_public_ip({ok, IP}) ->
    on_location(geo_check:get_location(IP));
on_public_ip({error, _Reason} = E) ->
    E.

on_location({ok, Loc}) ->
    {ok, normalize_location(Loc)};
on_location({error, _Reason} = E) ->
    E.

%% MaxMind returns lat/lng as floats and city/country as binaries
%% (or `undefined' when the DB has no entry). Drop undefined fields so
%% they don't mask a sibling's good value when this map is merged into
%% announcer opts.
normalize_location(Loc) ->
    Picked = #{
        country => maps:get(country, Loc, undefined),
        city    => maps:get(city,    Loc, undefined),
        lat     => maps:get(lat,     Loc, undefined),
        lng     => maps:get(lng,     Loc, undefined)
    },
    drop_undefined(Picked).

%% Best-effort hostname for the daemon. Used by realm dashboards to
%% render daemons by their machine name. Falls back to the BEAM node
%% name when the OS hostname call fails.
node_hostname() ->
    case inet:gethostname() of
        {ok, Name} -> list_to_binary(Name);
        _          -> atom_to_binary(node(), utf8)
    end.
