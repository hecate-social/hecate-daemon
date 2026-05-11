%%% @doc cache_invalidate: orchestrates cache invalidation with
%%% the cascade rules from PLAN_RESOLVE_MESH_NAMES_PART1 §6.2.
%%%
%%% Cascade rules (any upstream invalidation cascades downward):
%%%
%%%   L1 (realm pubkey) invalidates → L2 + L3 + L4 + L5 for that realm
%%%   L2 (realm directory) invalidates → L3 + L4 + L5 for that realm
%%%   L3 (endorsement)  invalidates → L4 + L5 for that (realm, path)
%%%   L4 (leaf record)  invalidates → L5 for that mri
%%%   L5 (composite)    invalidates → just itself (no downstream)
%%%
%%% Invalidations come from two sources:
%%%   - the two PMs (push events from macula:subscribe_records)
%%%   - cache_ttl_sweep (entries past expires_at)
%%%
%%% Operator commands also enter through here (`hecate names cache
%%% nuke', etc. — Phase 2 CLI work).
%%%
%%% Implementation: the cascade scans walk the affected layer's
%%% ETS table and pattern-match to find dependent entries. O(N)
%%% per cascade — acceptable for the cache sizes we expect (low
%%% thousands of entries). Indexing can come later if profiling
%%% shows the scan as a bottleneck.
%%% @end
-module(cache_invalidate).
-behaviour(gen_server).

-export([start_link/0, by_key/2, by_realm/1, by_member_path/2,
         by_mri/1, all/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Invalidate a single (layer, key) pair plus any cascades.
-spec by_key(Layer :: cache_records:layer(), Key :: term()) -> ok.
by_key(Layer, Key) ->
    gen_server:call(?MODULE, {by_key, Layer, Key}).

%% @doc Invalidate every cached entry tied to a given realm.
%% Used when an FRTL update changes the realm root pubkey, or
%% when the realm is removed from FRTL altogether.
-spec by_realm(RealmId :: binary()) -> ok.
by_realm(RealmId) ->
    gen_server:call(?MODULE, {by_realm, RealmId}).

%% @doc Invalidate L3 + L4 + L5 entries tied to a given
%% endorsement path (e.g., when an RME tombstone arrives).
-spec by_member_path(RealmId :: binary(), Path :: [binary()]) -> ok.
by_member_path(RealmId, Path) ->
    gen_server:call(?MODULE, {by_member_path, RealmId, Path}).

%% @doc Invalidate L4 + L5 entries for a given MRI (e.g., when a
%% leaf record version bump arrives via push).
-spec by_mri(Mri :: binary()) -> ok.
by_mri(Mri) ->
    gen_server:call(?MODULE, {by_mri, Mri}).

%% @doc Nuke everything (operator command; rare).
-spec all() -> ok.
all() ->
    gen_server:call(?MODULE, all).

%%====================================================================
%% gen_server callbacks
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{}}.

handle_call({by_key, Layer, Key}, _From, State) ->
    do_invalidate(Layer, Key),
    {reply, ok, State};
handle_call({by_realm, RealmId}, _From, State) ->
    do_invalidate(l1, RealmId),
    {reply, ok, State};
handle_call({by_member_path, RealmId, Path}, _From, State) ->
    do_invalidate(l3, {RealmId, Path}),
    {reply, ok, State};
handle_call({by_mri, Mri}, _From, State) ->
    %% Cascade L4 entries for this MRI (any record_type) + L5.
    cascade_l4_by_mri(Mri),
    cache_records:delete(l5, Mri),
    {reply, ok, State};
handle_call(all, _From, State) ->
    lists:foreach(fun(Layer) ->
        [cache_records:delete(Layer, K) || K <- cache_records:all_keys(Layer)]
    end, [l1, l2, l3, l4, l5]),
    {reply, ok, State};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Cascade implementation
%%====================================================================

%% Top-level dispatch: each layer invalidates itself + cascades
%% to all dependent downstream layers per PART1 §6.2.

do_invalidate(l1, RealmId) ->
    %% L1 → L2 + L3 + L4 + L5 for that realm
    cache_records:delete(l1, RealmId),
    cascade_l2_by_realm(RealmId),
    cascade_l3_by_realm(RealmId),
    cascade_l4_by_realm(RealmId),
    cascade_l5_by_realm(RealmId),
    ok;
do_invalidate(l2, RealmId) ->
    %% L2 → L3 + L4 + L5 for that realm
    cache_records:delete(l2, RealmId),
    cascade_l3_by_realm(RealmId),
    cascade_l4_by_realm(RealmId),
    cascade_l5_by_realm(RealmId),
    ok;
do_invalidate(l3, {RealmId, Path}) ->
    %% L3 → L4 + L5 for the affected (realm, path)
    cache_records:delete(l3, {RealmId, Path}),
    cascade_l4_by_realm_and_path(RealmId, Path),
    cascade_l5_by_realm_and_path(RealmId, Path),
    ok;
do_invalidate(l4, {Mri, _RecordType} = Key) ->
    %% L4 → L5 for that MRI
    cache_records:delete(l4, Key),
    cache_records:delete(l5, Mri),
    ok;
do_invalidate(l5, Mri) ->
    %% L5 → terminal (no downstream)
    cache_records:delete(l5, Mri),
    ok.

cascade_l2_by_realm(RealmId) ->
    cache_records:delete(l2, RealmId).

cascade_l3_by_realm(RealmId) ->
    Keys = cache_records:all_keys(l3),
    lists:foreach(fun({R, _Path} = K) when R =:= RealmId ->
                          cache_records:delete(l3, K);
                     (_) -> ok
                  end, Keys).

cascade_l4_by_realm(RealmId) ->
    Keys = cache_records:all_keys(l4),
    lists:foreach(fun({Mri, _Type} = K) ->
        case mri_realm(Mri) of
            RealmId -> cache_records:delete(l4, K);
            _       -> ok
        end
    end, Keys).

cascade_l5_by_realm(RealmId) ->
    Keys = cache_records:all_keys(l5),
    lists:foreach(fun(Mri) ->
        case mri_realm(Mri) of
            RealmId -> cache_records:delete(l5, Mri);
            _       -> ok
        end
    end, Keys).

cascade_l4_by_realm_and_path(RealmId, Path) ->
    Keys = cache_records:all_keys(l4),
    lists:foreach(fun({Mri, _Type} = K) ->
        case mri_realm_and_path(Mri) of
            {RealmId, Path} -> cache_records:delete(l4, K);
            _               -> ok
        end
    end, Keys).

cascade_l5_by_realm_and_path(RealmId, Path) ->
    Keys = cache_records:all_keys(l5),
    lists:foreach(fun(Mri) ->
        case mri_realm_and_path(Mri) of
            {RealmId, Path} -> cache_records:delete(l5, Mri);
            _               -> ok
        end
    end, Keys).

cascade_l4_by_mri(Mri) ->
    Keys = cache_records:all_keys(l4),
    lists:foreach(fun({M, _Type} = K) when M =:= Mri ->
                          cache_records:delete(l4, K);
                     (_) -> ok
                  end, Keys).

%%====================================================================
%% MRI helpers — extract realm + path from cached MRI strings.
%% Station MRIs have no realm in the macula sense (the realm field
%% IS the pubkey); they don't tie to realm-cascade rules.
%%====================================================================

mri_realm(<<"mri:station:", _/binary>>) ->
    undefined;
mri_realm(Mri) when is_binary(Mri) ->
    case macula_mri:parse(Mri) of
        {ok, #{realm := Realm}} -> Realm;
        _                       -> undefined
    end;
mri_realm(_) ->
    undefined.

mri_realm_and_path(<<"mri:station:", _/binary>>) ->
    undefined;
mri_realm_and_path(Mri) when is_binary(Mri) ->
    case macula_mri:parse(Mri) of
        {ok, #{realm := Realm, path := Path}} -> {Realm, Path};
        _                                     -> undefined
    end;
mri_realm_and_path(_) ->
    undefined.
