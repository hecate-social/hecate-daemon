%%% @doc Process Manager: on a structural realm-record change
%%% (realm_directory or FRTL version-bump observed via
%%% `macula:subscribe_records/3'), invalidate the affected realm's
%%% cache subtree so the next resolve fetches fresh data rather
%%% than serving stale entries until their TTL.
%%%
%%% Watches:
%%%   - `realm_directory' (type 0x03) — admin_key rotation, policy
%%%     URL change, version bump. Envelope key is the realm pubkey
%%%     → reverse-lookup the realm-id in L1 → invalidate that
%%%     realm's subtree (precise).
%%%   - `foundation_realm_trust_list' (type 0x0F) — a realm was
%%%     added/removed/re-keyed in the trust list. Envelope key is
%%%     the foundation pubkey → find every realm anchored to that
%%%     foundation (via `trust_anchors:list/0') → invalidate each.
%%%
%%% "Warm cache" caveat: this PM currently does prompt INVALIDATION
%%% on structural change — the cache stays warm-with-fresh-data
%%% rather than warm-with-stale-data. Actual pre-FETCH (proactively
%%% re-verifying + re-populating L1/L2 from the change) is a
%%% follow-up; it needs care around whether the pushed record is
%%% trustworthy enough to install without re-walking the chain
%%% against FRTL. For now the next resolve does the re-walk lazily.
%%%
%%% Lives in this slice (target domain: cache_records). Subscribes
%%% to events emitted by the mesh substrate.
%%%
%%% Mesh-pool bootstrap: like the sibling invalidation PM, this PM
%%% has no pool handle at boot, so on start it polls
%%% `hecate_mesh:get_client/0' every `mesh_subscribe_retry_ms'
%%% until the daemon's V2 pool is up, then subscribes to the
%%% watched record types on it; it monitors the pool and
%%% re-bootstraps if it dies. `subscribe/1' remains as an
%%% explicit-override entry point but is no longer required.
%%% @end
-module(on_realm_directory_changed_warm_cache).
-behaviour(gen_server).

-export([start_link/0, subscribe/1, on_record/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TYPE_REALM_DIRECTORY,             16#03).
-define(TYPE_FOUNDATION_REALM_TRUST_LIST, 16#0F).

-define(WATCHED_TYPES, [?TYPE_REALM_DIRECTORY, ?TYPE_FOUNDATION_REALM_TRUST_LIST]).

%% Fallback re-poll interval for the mesh-pool bootstrap when the app
%% env isn't set (e.g. CT suites that don't load resolve_mesh_names).
-define(BOOTSTRAP_RETRY_MS_DEFAULT, 5_000).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Subscribe to the watched record types via the given mesh
%% pool. Normally the PM bootstraps this itself (see module doc);
%% this entry point lets a caller force a (re)subscribe.
-spec subscribe(Pool :: pid()) -> ok.
subscribe(Pool) ->
    gen_server:call(?MODULE, {subscribe, Pool}).

%% @doc Handle a single record-observed push event. Exposed for
%% tests; the macula subscribe_records callback forwards here.
-spec on_record(TypeTag :: 0..255, RecordMap :: map()) -> ok.
on_record(TypeTag, RecordMap) ->
    gen_server:cast(?MODULE, {on_record, TypeTag, RecordMap}).

%%====================================================================
%% gen_server callbacks
%%====================================================================

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    self() ! bootstrap_subscribe,
    {ok, #{pool => undefined, subs => [], pool_mon => undefined}}.

handle_call({subscribe, Pool}, _From, State) ->
    {reply, ok, do_subscribe(Pool, State)};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast({on_record, ?TYPE_REALM_DIRECTORY, Rec}, State) ->
    handle_dir_changed(Rec),
    {noreply, State};
handle_cast({on_record, ?TYPE_FOUNDATION_REALM_TRUST_LIST, Rec}, State) ->
    handle_frtl_changed(Rec),
    {noreply, State};
handle_cast({on_record, _OtherType, _Rec}, State) ->
    {noreply, State};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(bootstrap_subscribe, #{pool := Cur} = State) ->
    case live_pool() of
        {ok, Cur} when is_pid(Cur) ->
            {noreply, State};
        {ok, Pool} ->
            {noreply, do_subscribe(Pool, State)};
        none ->
            erlang:send_after(retry_ms(), self(), bootstrap_subscribe),
            {noreply, State}
    end;
handle_info({'DOWN', Mon, process, _Pid, _Reason}, #{pool_mon := Mon} = State) ->
    erlang:send_after(retry_ms(), self(), bootstrap_subscribe),
    {noreply, State#{pool => undefined, subs => [], pool_mon => undefined}};
handle_info(_Info, S) -> {noreply, S}.

terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Subscription plumbing
%%====================================================================

do_subscribe(Pool, State) ->
    OldPool = maps:get(pool, State, undefined),
    [catch macula:unsubscribe_records(OldPool, Ref)
     || {_T, Ref} <- maps:get(subs, State, []), is_pid(OldPool)],
    case maps:get(pool_mon, State, undefined) of
        undefined -> ok;
        OldMon    -> catch erlang:demonitor(OldMon, [flush])
    end,
    NewMon = erlang:monitor(process, Pool),
    NewSubs = lists:filtermap(fun(Type) ->
        Cb = fun(Rec) -> on_record(Type, Rec) end,
        case catch macula:subscribe_records(Pool, Type, Cb) of
            {ok, Ref} -> {true, {Type, Ref}};
            _Other    -> false
        end
    end, ?WATCHED_TYPES),
    logger:info("[on_realm_directory_changed_warm_cache] subscribed to ~b/~b "
                "record type(s) on mesh pool ~p",
                [length(NewSubs), length(?WATCHED_TYPES), Pool]),
    State#{pool => Pool, subs => NewSubs, pool_mon => NewMon}.

live_pool() ->
    case catch hecate_mesh:get_client() of
        {ok, P} when is_pid(P) -> {ok, P};
        _                      -> none
    end.

retry_ms() ->
    application:get_env(resolve_mesh_names, mesh_subscribe_retry_ms,
                        ?BOOTSTRAP_RETRY_MS_DEFAULT).

%%====================================================================
%% Handlers
%%====================================================================

handle_dir_changed(#{key := RealmPk}) when is_binary(RealmPk),
                                           byte_size(RealmPk) =:= 32 ->
    case cache_records:realm_id_for_pubkey(RealmPk) of
        {ok, RealmId} ->
            cache_invalidate:by_realm(RealmId),
            catch watch_mri:realm_changed(RealmId, changed),
            ok;
        not_found ->
            ok
    end;
handle_dir_changed(_) ->
    ok.

handle_frtl_changed(#{key := FoundationPk}) when is_binary(FoundationPk),
                                                 byte_size(FoundationPk) =:= 32 ->
    %% Invalidate every realm anchored to this foundation + notify
    %% any watchers in those realms.
    Affected = [RealmId || {RealmId, FPk} <- trust_anchors:list(),
                            FPk =:= FoundationPk],
    [begin
         cache_invalidate:by_realm(RealmId),
         catch watch_mri:realm_changed(RealmId, changed)
     end || RealmId <- Affected],
    ok;
handle_frtl_changed(_) ->
    ok.
