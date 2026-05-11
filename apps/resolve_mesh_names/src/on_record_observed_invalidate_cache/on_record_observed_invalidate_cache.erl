%%% @doc Process Manager: on `record_observed' push events from the
%%% mesh (delivered via `macula:subscribe_records/3'), invalidate
%%% the affected cache entries.
%%%
%%% Watches the record types that signal a REVOCATION or
%%% SUPERSESSION the cache must react to immediately:
%%%   - `tombstone' (type 0x0C) — a record was killed. Dispatch by
%%%     `superseded_type':
%%%       * realm_directory (0x03): `superseded_key' IS the realm
%%%         pubkey → reverse-lookup the realm-id in L1 → invalidate
%%%         that realm's subtree (precise).
%%%       * realm_member_endorsement (0x05): the storage key is a
%%%         SHA-256 of (realm_pk ‖ member_pk) — can't reverse it,
%%%         so invalidate broadly. We delete every L3/L4/L5 entry
%%%         (coarse but correct — RME tombstones are rare).
%%%       * leaf types / FRTL / anything else: can't pin the
%%%         affected realm from a hashed key → nuke L5 (forces
%%%         re-resolution of everything). Coarse but correct.
%%%   - `realm_member_endorsement' (type 0x05) — a NEW version
%%%     arrived (member added, roles changed, validity window
%%%     extended). Envelope key is the realm pubkey → reverse-lookup
%%%     → invalidate that realm's subtree (the RME payload also
%%%     carries `member_node', but the cache doesn't yet index L4
%%%     by signer so realm-grain is the precision we can deliver).
%%%
%%% (`realm_directory' and `foundation_realm_trust_list' version-
%%% bumps are watched by the sibling PM `on_realm_directory_changed_warm_cache'.)
%%%
%%% Lives in this slice (target domain: cache_records). Subscribes
%%% to events emitted by the mesh substrate (source domain). The
%%% PM doesn't subscribe at boot — it has no Pool handle yet; the
%%% mesh-client wiring calls `subscribe/1' once `hecate_mesh' is
%%% up. Until then the PM is inert (correctly waiting, not lying).
%%%
%%% `on_record/2' is exposed for testing — the macula callback
%%% just forwards to it.
%%% @end
-module(on_record_observed_invalidate_cache).
-behaviour(gen_server).

-export([start_link/0, subscribe/1, on_record/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TYPE_REALM_DIRECTORY,              16#03).
-define(TYPE_REALM_MEMBER_ENDORSEMENT,     16#05).
-define(TYPE_TOMBSTONE,                    16#0C).

%% Record types this PM subscribes to.
-define(WATCHED_TYPES, [?TYPE_TOMBSTONE, ?TYPE_REALM_MEMBER_ENDORSEMENT]).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Subscribe to the watched record types via the given mesh
%% pool. Called by the mesh-client wiring once `hecate_mesh' is up.
%% Idempotent — re-calling re-subscribes (old subs are dropped).
-spec subscribe(Pool :: pid()) -> ok.
subscribe(Pool) ->
    gen_server:call(?MODULE, {subscribe, Pool}).

%% @doc Handle a single record-observed push event. Exposed for
%% tests; the macula subscribe_records callback just forwards here.
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
    Old = maps:get(subs, State, []),
    [catch macula:unsubscribe_records(maps:get(pool, State), Ref)
     || {_T, Ref} <- Old, maps:get(pool, State) =/= undefined],
    NewSubs = lists:filtermap(fun(Type) ->
        Cb = fun(Rec) -> on_record(Type, Rec) end,
        case macula:subscribe_records(Pool, Type, Cb) of
            {ok, Ref}      -> {true, {Type, Ref}};
            {error, _Why}  -> false
        end
    end, ?WATCHED_TYPES),
    {reply, ok, State#{pool => Pool, subs => NewSubs}};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast({on_record, ?TYPE_TOMBSTONE, Rec}, State) ->
    handle_tombstone(Rec),
    {noreply, State};
handle_cast({on_record, ?TYPE_REALM_MEMBER_ENDORSEMENT, Rec}, State) ->
    handle_rme_observed(Rec),
    {noreply, State};
handle_cast({on_record, _OtherType, _Rec}, State) ->
    {noreply, State};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Tombstone handling
%%====================================================================

handle_tombstone(#{payload := P}) when is_map(P) ->
    SupType = maps:get({text, <<"superseded_type">>}, P, undefined),
    SupKey  = maps:get({text, <<"superseded_key">>}, P, undefined),
    dispatch_tombstone(SupType, SupKey);
handle_tombstone(_) ->
    ok.

%% realm_directory tombstone: superseded_key IS the realm pubkey.
dispatch_tombstone(?TYPE_REALM_DIRECTORY, RealmPk)
  when is_binary(RealmPk), byte_size(RealmPk) =:= 32 ->
    case cache_records:realm_id_for_pubkey(RealmPk) of
        {ok, RealmId} ->
            cache_invalidate:by_realm(RealmId),
            catch watch_mri:realm_changed(RealmId, tombstoned),
            ok;
        not_found ->
            ok       %% we don't cache this realm; nothing to do
    end;
%% Any other tombstone (RME, FRTL, leaf types): can't reverse the
%% hashed storage key → nuke L5 so the next resolve re-walks.
%% RME/FRTL also force L3 re-validation on the next chain walk
%% because verify_trust_chain re-checks expires_at + signature.
%% (No watch notification — we can't pin the affected realm from a
%% hashed key, and a broadcast-to-all-watchers would be too
%% chatty; watchers get fresh data on their next resolve or on a
%% subsequent realm-scoped change.)
dispatch_tombstone(_OtherType, _SupKey) ->
    [cache_records:delete(l5, K) || K <- cache_records:all_keys(l5)],
    ok.

%%====================================================================
%% RME version-bump handling
%%====================================================================

handle_rme_observed(#{key := RealmPk}) when is_binary(RealmPk),
                                            byte_size(RealmPk) =:= 32 ->
    case cache_records:realm_id_for_pubkey(RealmPk) of
        {ok, RealmId} ->
            cache_invalidate:by_realm(RealmId),
            catch watch_mri:realm_changed(RealmId, changed),
            ok;
        not_found ->
            ok
    end;
handle_rme_observed(_) ->
    ok.
