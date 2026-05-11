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
%%% to events emitted by the mesh substrate. Like the sibling
%%% invalidation PM, it doesn't subscribe at boot — the mesh-client
%%% wiring calls `subscribe/1' once `hecate_mesh' is up.
%%% @end
-module(on_realm_directory_changed_warm_cache).
-behaviour(gen_server).

-export([start_link/0, subscribe/1, on_record/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TYPE_REALM_DIRECTORY,             16#03).
-define(TYPE_FOUNDATION_REALM_TRUST_LIST, 16#0F).

-define(WATCHED_TYPES, [?TYPE_REALM_DIRECTORY, ?TYPE_FOUNDATION_REALM_TRUST_LIST]).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Subscribe to the watched record types via the given mesh
%% pool. Called by the mesh-client wiring once `hecate_mesh' is up.
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
    {ok, #{pool => undefined, subs => []}}.

handle_call({subscribe, Pool}, _From, State) ->
    [catch macula:unsubscribe_records(maps:get(pool, State), Ref)
     || {_T, Ref} <- maps:get(subs, State, []),
        maps:get(pool, State) =/= undefined],
    NewSubs = lists:filtermap(fun(Type) ->
        Cb = fun(Rec) -> on_record(Type, Rec) end,
        case macula:subscribe_records(Pool, Type, Cb) of
            {ok, Ref}     -> {true, {Type, Ref}};
            {error, _Why} -> false
        end
    end, ?WATCHED_TYPES),
    {reply, ok, State#{pool => Pool, subs => NewSubs}};
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

handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Handlers
%%====================================================================

handle_dir_changed(#{key := RealmPk}) when is_binary(RealmPk),
                                           byte_size(RealmPk) =:= 32 ->
    case cache_records:realm_id_for_pubkey(RealmPk) of
        {ok, RealmId} -> cache_invalidate:by_realm(RealmId);
        not_found     -> ok
    end;
handle_dir_changed(_) ->
    ok.

handle_frtl_changed(#{key := FoundationPk}) when is_binary(FoundationPk),
                                                 byte_size(FoundationPk) =:= 32 ->
    %% Invalidate every realm anchored to this foundation.
    Affected = [RealmId || {RealmId, FPk} <- trust_anchors:list(),
                            FPk =:= FoundationPk],
    [cache_invalidate:by_realm(RealmId) || RealmId <- Affected],
    ok;
handle_frtl_changed(_) ->
    ok.
