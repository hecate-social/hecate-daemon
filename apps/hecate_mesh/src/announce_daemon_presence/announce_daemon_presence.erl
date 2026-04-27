%%% @doc Daemon presence announcer.
%%%
%%% Mirrors `hecate_station_announcer' in daemon space — periodically
%%% publishes a signed `node_record' (`type=0x01') tagged with
%%% `kind=daemon' into the relay-mesh DHT via the per-relay
%%% `macula_station_client' pool. Records are refreshed before TTL
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
    timer_ref      :: reference() | undefined
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
    {ok, #state{ttl_ms = Ttl, refresh_ms = RefreshMs}}.

handle_call(_Msg, _From, S) ->
    {reply, {error, unknown_call}, S}.

handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info({refresh, _OldRef}, #state{ttl_ms = Ttl} = S) ->
    Next = on_refresh_result(publish_node_record(Ttl), S),
    {noreply, schedule(Next, S)};
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
publish_node_record(TtlMs) ->
    %% hecate_identity may not be up yet when we boot — both apps
    %% are children of the daemon's top-level sup and there is no
    %% start-order guarantee across siblings. `gen_server:call/2'
    %% on a non-existent server raises `exit({noproc, _})'; catch
    %% it and surface as `{error, no_identity}' so the announcer's
    %% backoff loop applies.
    try hecate_identity:signing_keypair() of
        {ok, KeyPair} ->
            do_publish(KeyPair, TtlMs);
        not_initialized ->
            logger:debug("[announce_daemon_presence] identity not initialised"),
            {error, no_identity}
    catch
        exit:{noproc, _} ->
            logger:debug("[announce_daemon_presence] hecate_identity not running"),
            {error, no_identity}
    end.

do_publish(KeyPair, TtlMs) ->
    Pub      = macula_identity:public(KeyPair),
    Hostname = node_hostname(),
    Opts     = #{ttl_ms   => TtlMs,
                 kind     => <<"daemon">>,
                 hostname => Hostname},
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

%% Best-effort hostname for the daemon. Used by realm dashboards to
%% render daemons by their machine name. Falls back to the BEAM node
%% name when the OS hostname call fails.
node_hostname() ->
    case inet:gethostname() of
        {ok, Name} -> list_to_binary(Name);
        _          -> atom_to_binary(node(), utf8)
    end.
