%%% @doc verify_trust_chain desk: 5-link state machine driver.
%%%
%%% State sequence (PLAN_RESOLVE_MESH_NAMES_PART1 §5.2):
%%%   need_anchor → need_frtl → have_frtl → need_dir → have_dir →
%%%   need_leaf → have_leaf → need_endorse → have_endorse →
%%%   [need_hd?] → verified
%%%
%%% Note the order differs slightly from PART1 §5.2: we fetch the
%%% leaf BEFORE the endorsement, because the SDK's RME storage key
%%% is `sha256("rme_member_endorse" || realm_pk || member_pk)' —
%%% we need the member_pk to compute the lookup, and the leaf
%%% record is what carries it (the leaf's `key' field IS the
%%% signer's pubkey IS the member_pk). Top-down ordering would
%%% require either a separate index or a scan over all RMEs in
%%% the realm; bottom-up is single-lookup-per-state.
%%%
%%% Each transition reads from `cache_records' first, falls back
%%% to `lookup_via_dht' on miss, populates the cache on success.
%%% Failures bubble out as typed `{error, atom()}' matching
%%% PART1 §6 — the bridge translates to wire-protocol responses.
%%%
%%% Driver is implemented as a fold over a list of step functions.
%%% Each step takes a `Ctx' map, reads what it needs, populates
%%% more, returns `{ok, NewCtx}' or `{error, Reason}'. Halt-on-error
%%% via the fold short-circuits on the first failure.
%%% @end
-module(verify_trust_chain).
-behaviour(gen_server).

-export([start_link/0, verify/3, verify/4, verify/5]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TYPE_REALM_DIRECTORY,              16#03).
-define(TYPE_REALM_MEMBER_ENDORSEMENT,     16#05).
-define(TYPE_FOUNDATION_REALM_TRUST_LIST,  16#0F).
-define(TYPE_HOSTED_ADDRESS_MAP,           16#14).

%% Storage-key domains — MUST match macula_record:storage_key/1 in
%% the SDK. realm_directory's storage key is the realm pubkey
%% itself (no domain prefix); FRTL + RME hash under these domains.
-define(STORAGE_DOMAIN_FOUND_TRUST,    <<"foundation_realm_trust_list">>).
-define(STORAGE_DOMAIN_MEMBER_ENDORSE, <<"member_endorsement">>).

%%====================================================================
%% Public API
%%====================================================================

%% @equiv verify(Pool, Mri, undefined, LeafType, #{})
-spec verify(Pool :: pid(), Mri :: binary(), LeafType :: atom()) ->
    {ok, map()} | {error, atom()}.
verify(Pool, Mri, LeafType) ->
    verify(Pool, Mri, undefined, LeafType, #{}).

%% @equiv verify(Pool, Mri, LeafStorageKey, LeafType, #{})
-spec verify(Pool :: pid(),
             Mri  :: binary(),
             LeafStorageKey :: binary() | undefined,
             LeafType :: atom()) ->
    {ok, map()} | {error, atom()}.
verify(Pool, Mri, LeafStorageKey, LeafType) ->
    verify(Pool, Mri, LeafStorageKey, LeafType, #{}).

%% @doc Walk the 5-link chain for an MRI + leaf-record-type.
%% Opts:
%%   `find_fn'         dependency-injected DHT lookup (forwarded
%%                     to lookup_via_dht; default `macula:find_record/2')
%%   `max_attempts'    DHT retries
%%   `now_ms'          override clock for tests
%%   `grace_window_ms' clock-skew tolerance for FRTL expiry
-spec verify(Pool :: pid(),
             Mri  :: binary(),
             LeafStorageKey :: binary() | undefined,
             LeafType :: atom(),
             Opts :: map()) ->
    {ok, map()} | {error, atom()}.
verify(Pool, Mri, LeafStorageKey, LeafType, Opts) ->
    case derive_leaf_storage_key(Mri, LeafStorageKey, LeafType) of
        {ok, Key} ->
            case parse_realm_id(Mri) of
                {ok, RealmId} ->
                    NowMs = maps:get(now_ms, Opts,
                                     erlang:system_time(millisecond)),
                    Ctx = #{pool      => Pool,
                            mri       => Mri,
                            realm_id  => RealmId,
                            leaf_type => LeafType,
                            leaf_key  => Key,
                            now_ms    => NowMs,
                            opts      => merge_opts(Opts)},
                    walk_steps(steps(), Ctx);
                {error, _} = E ->
                    E
            end;
        {error, _} = E ->
            E
    end.

merge_opts(Opts) ->
    Defaults = default_opts(),
    maps:merge(Defaults, Opts).

steps() ->
    [
        fun do_need_anchor/1,
        fun do_need_frtl/1,
        fun do_need_dir/1,
        fun do_need_leaf/1,
        fun do_need_endorse/1,
        fun do_maybe_need_hd/1,
        fun do_finalise/1
    ].

walk_steps([], #{verified_record := V}) ->
    {ok, V};
walk_steps([Step | Rest], Ctx) ->
    case Step(Ctx) of
        {ok, NewCtx}    -> walk_steps(Rest, NewCtx);
        {error, _} = E  -> E
    end.

%%====================================================================
%% Step 1: need_anchor — read foundation pubkey from trust_anchors
%%====================================================================

do_need_anchor(#{realm_id := RealmId} = Ctx) ->
    case trust_anchors:get(RealmId) of
        {ok, FoundationPk}      -> {ok, Ctx#{foundation_pk => FoundationPk}};
        {error, no_trust_root}  -> {error, no_trust_root}
    end.

%%====================================================================
%% Step 2: need_frtl + have_frtl — fetch FRTL, verify, derive realm_pk
%%====================================================================

do_need_frtl(Ctx) ->
    #{pool := Pool, realm_id := RealmId, foundation_pk := FoundationPk,
      now_ms := NowMs, opts := Opts} = Ctx,
    %% Fast path: cache_records L1 has the (realm_id → realm_pk) mapping.
    case cache_records:get(l1, RealmId) of
        {ok, RealmPk, _ExpiresAt} ->
            {ok, Ctx#{realm_pk => RealmPk}};
        miss ->
            %% Cold path: fetch FRTL, verify, locate our realm,
            %% cache the result.
            FrtlKey = sha256(<<?STORAGE_DOMAIN_FOUND_TRUST/binary,
                               FoundationPk/binary>>),
            case lookup_via_dht:find(Pool, FrtlKey, find_opts(Opts)) of
                {ok, FrtlRecord} ->
                    GraceMs = maps:get(grace_window_ms, Opts, 0),
                    case verify_frtl:verify(FrtlRecord, FoundationPk,
                                            #{now_ms => NowMs,
                                              grace_window_ms => GraceMs}) of
                        {ok, _FrtlPayload} ->
                            %% Determine realm_pk for this RealmId.
                            %% In Phase 1.4 we use the configured
                            %% mapping (compiled_in_realm_pubkeys); a
                            %% later phase scans realm_directory
                            %% records to discover unknown realm pks.
                            case configured_realm_pk(RealmId) of
                                {ok, RealmPk} ->
                                    case is_realm_trusted(RealmPk, FrtlRecord) of
                                        true ->
                                            cache_l1(RealmId, RealmPk, FrtlRecord),
                                            {ok, Ctx#{realm_pk => RealmPk}};
                                        false ->
                                            {error, realm_not_trusted}
                                    end;
                                {error, _} ->
                                    {error, realm_not_trusted}
                            end;
                        {error, _} = E ->
                            E
                    end;
                {error, _} ->
                    {error, trust_list_unavailable}
            end
    end.

%%====================================================================
%% Step 3: need_dir + have_dir — fetch realm_directory, verify
%%====================================================================

do_need_dir(Ctx) ->
    #{pool := Pool, realm_id := RealmId, realm_pk := RealmPk,
      opts := Opts} = Ctx,
    case cache_records:get(l2, RealmId) of
        {ok, DirPayload, _} ->
            AdminKey = maps:get({text, <<"admin_key">>}, DirPayload, undefined),
            {ok, Ctx#{dir_payload => DirPayload, admin_key => AdminKey}};
        miss ->
            %% realm_directory's storage key IS the realm pubkey
            %% (per macula_record:storage_key/1) — no domain hash.
            DirKey = RealmPk,
            case lookup_via_dht:find(Pool, DirKey, find_opts(Opts)) of
                {ok, DirRecord} ->
                    case verify_realm_directory:verify(DirRecord, RealmPk) of
                        {ok, DirPayload} ->
                            cache_l2(RealmId, DirPayload, DirRecord),
                            AdminKey = maps:get({text, <<"admin_key">>},
                                                DirPayload, undefined),
                            {ok, Ctx#{dir_payload => DirPayload,
                                      admin_key   => AdminKey}};
                        {error, _} = E ->
                            E
                    end;
                {error, _} ->
                    {error, realm_dir_unavailable}
            end
    end.

%%====================================================================
%% Step 4: need_leaf + have_leaf — fetch leaf record by storage key
%% (note: SDK forces bottom-up — we need the leaf's `key' field to
%% know member_pk before we can compute the RME storage key)
%%====================================================================

do_need_leaf(Ctx) ->
    #{pool := Pool, mri := Mri, leaf_type := LeafType,
      leaf_key := LeafKey, opts := Opts} = Ctx,
    L4Key = {Mri, LeafType},
    case cache_records:get(l4, L4Key) of
        {ok, Leaf, _} ->
            {ok, Ctx#{leaf_record => Leaf,
                      member_pk   => leaf_signer(Leaf)}};
        miss ->
            case lookup_via_dht:find(Pool, LeafKey, find_opts(Opts)) of
                {ok, Leaf} ->
                    %% Don't cache yet — verification happens below
                    %% in verify_leaf_record after we know member_pk.
                    {ok, Ctx#{leaf_record => Leaf,
                              member_pk   => leaf_signer(Leaf)}};
                {error, _} ->
                    {error, sig_indeterminate}
            end
    end.

%%====================================================================
%% Step 5: need_endorse + have_endorse — fetch RME, verify
%%====================================================================

do_need_endorse(Ctx) ->
    #{pool := Pool, realm_id := RealmId, realm_pk := RealmPk,
      admin_key := AdminKey, member_pk := MemberPk,
      mri := _Mri, now_ms := NowMs, opts := Opts} = Ctx,
    %% RME path: stored at sha256("rme_member_endorse" || realm_pk || member_pk).
    RmeKey = sha256(<<?STORAGE_DOMAIN_MEMBER_ENDORSE/binary,
                      RealmPk/binary, MemberPk/binary>>),
    %% Cache key: (RealmId, member_pk) — distinct from the sha256
    %% storage key so cache lookups don't need to recompute the hash.
    L3Key = {RealmId, MemberPk},
    case cache_records:get(l3, L3Key) of
        {ok, _CachedMember, _} ->
            {ok, Ctx};
        miss ->
            case lookup_via_dht:find(Pool, RmeKey, find_opts(Opts)) of
                {ok, RmeRecord} ->
                    case verify_endorsement:verify(RmeRecord, RealmPk, AdminKey,
                                                   #{now_ms => NowMs}) of
                        {ok, ConfirmedMember} when ConfirmedMember =:= MemberPk ->
                            cache_l3(RealmId, MemberPk, RmeRecord),
                            {ok, Ctx};
                        {ok, _OtherMember} ->
                            %% RME is for a different member — should
                            %% not happen given the storage key but
                            %% catch it for paranoia.
                            {error, name_not_endorsed};
                        {error, _} = E ->
                            E
                    end;
                {error, _} ->
                    %% Phase 1: no coverage_proof support yet, so
                    %% treat missing RME as coverage_unknown rather
                    %% than name_not_endorsed (PART1 §6: honest
                    %% "I don't know" beats forged NXDOMAIN).
                    {error, coverage_unknown}
            end
    end.

%%====================================================================
%% Step 6: maybe_need_hd — only if leaf is hosted_address_map
%%====================================================================

do_maybe_need_hd(Ctx) ->
    #{leaf_record := Leaf, realm_pk := RealmPk, now_ms := NowMs} = Ctx,
    case maps:get(type, Leaf, undefined) of
        ?TYPE_HOSTED_ADDRESS_MAP ->
            case extract_host_delegation(Leaf) of
                {ok, Delegation, DaemonPk} ->
                    case verify_host_delegation:verify(Delegation, DaemonPk,
                                                       RealmPk,
                                                       #{now_ms => NowMs}) of
                        ok            -> {ok, Ctx#{host_delegation => Delegation}};
                        {error, _} = E -> E
                    end;
                {error, _} = E ->
                    E
            end;
        _ ->
            {ok, Ctx}
    end.

extract_host_delegation(#{payload := P}) when is_map(P) ->
    case maps:get({text, <<"delegation">>}, P, undefined) of
        D when is_map(D) ->
            DaemonPk = maps:get(daemon_pubkey, D, undefined),
            {ok, D, DaemonPk};
        _ ->
            {error, delegation_invalid}
    end;
extract_host_delegation(_) ->
    {error, delegation_invalid}.

%%====================================================================
%% Step 7: finalise — verify leaf signature, build verified_record,
%% cache L4 + L5
%%====================================================================

do_finalise(Ctx) ->
    #{leaf_record := Leaf, member_pk := MemberPk, mri := Mri,
      leaf_type := LeafType, realm_id := RealmId, realm_pk := RealmPk,
      foundation_pk := FoundationPk, now_ms := NowMs} = Ctx,
    case verify_leaf_record:verify(Leaf, MemberPk, #{now_ms => NowMs}) of
        {ok, _} ->
            VerifiedRecord = #{
                record_type   => LeafType,
                mri           => Mri,
                payload       => maps:get(payload, Leaf, #{}),
                signer_pubkey => MemberPk,
                chain         => build_chain_metadata(FoundationPk, RealmPk,
                                                       MemberPk, RealmId),
                expires_at    => maps:get(expires_at, Leaf, 0),
                version       => maps:get(version, Leaf, undefined),
                observed_at   => NowMs
            },
            cache_l4(Mri, LeafType, Leaf),
            cache_l5(Mri, [VerifiedRecord]),
            {ok, Ctx#{verified_record => VerifiedRecord}};
        {error, _} = E ->
            E
    end.

build_chain_metadata(FoundationPk, RealmPk, MemberPk, _RealmId) ->
    [
        #{type => frtl,        pubkey => FoundationPk},
        #{type => realm_dir,   pubkey => RealmPk},
        #{type => endorsement, pubkey => MemberPk},
        #{type => leaf,        pubkey => MemberPk}
    ].

%%====================================================================
%% Caching helpers — uniform TTL/version derivation
%%====================================================================

cache_l1(RealmId, RealmPk, FrtlRecord) ->
    Exp = record_expires_at(FrtlRecord, default_l1_ttl_ms()),
    Ver = maps:get(version, FrtlRecord, 0),
    cache_records:put(l1, RealmId, RealmPk, Exp, Ver).

cache_l2(RealmId, DirPayload, DirRecord) ->
    Exp = record_expires_at(DirRecord, default_l2_ttl_ms()),
    Ver = maps:get(version, DirRecord, 0),
    cache_records:put(l2, RealmId, DirPayload, Exp, Ver).

cache_l3(RealmId, MemberPk, RmeRecord) ->
    Exp = record_expires_at(RmeRecord, default_l3_ttl_ms()),
    Ver = maps:get(version, RmeRecord, 0),
    cache_records:put(l3, {RealmId, MemberPk}, MemberPk, Exp, Ver).

cache_l4(Mri, LeafType, LeafRecord) ->
    Exp = record_expires_at(LeafRecord, default_l4_ttl_ms()),
    Ver = maps:get(version, LeafRecord, 0),
    cache_records:put(l4, {Mri, LeafType}, LeafRecord, Exp, Ver).

cache_l5(Mri, VerifiedRecords) ->
    Exp = erlang:system_time(millisecond) + default_l5_ttl_ms(),
    cache_records:put(l5, Mri, VerifiedRecords, Exp, 0).

record_expires_at(#{expires_at := EA}, _Default) when is_integer(EA), EA > 0 ->
    EA;
record_expires_at(_, Default) ->
    erlang:system_time(millisecond) + Default.

default_l1_ttl_ms() -> 3600 * 1000.       %% hours
default_l2_ttl_ms() -> 600 * 1000.        %% 10 minutes
default_l3_ttl_ms() -> 600 * 1000.        %% 10 minutes
default_l4_ttl_ms() -> 60 * 1000.         %% 1 minute
default_l5_ttl_ms() -> 60 * 1000.         %% 1 minute

%%====================================================================
%% Helpers — FRTL realm-pubkey lookup, MRI parsing, leaf storage key
%%====================================================================

is_realm_trusted(RealmPk, #{payload := #{{text, <<"realms_trusted">>} := List}})
  when is_list(List) ->
    lists:member(RealmPk, List);
is_realm_trusted(_, _) ->
    false.

%% Phase 1.4: realm_id → realm_pk mapping comes from app env.
%% Phase 1.5+ will populate this via realm_directory scans on FRTL
%% receipt, then cache in L1 keyed by (realm_id).
configured_realm_pk(RealmId) ->
    Map = application:get_env(resolve_mesh_names, compiled_in_realm_pubkeys, []),
    case lists:keyfind(RealmId, 1, Map) of
        {_, Pk} when is_binary(Pk), byte_size(Pk) =:= 32 -> {ok, Pk};
        _ -> {error, no_realm_pubkey_configured}
    end.

leaf_signer(#{key := K}) when is_binary(K), byte_size(K) =:= 32 -> K;
leaf_signer(_) -> undefined.

parse_realm_id(<<"mri:station:", _/binary>>) ->
    %% Station MRIs have no realm in the macula sense — they're
    %% self-rooted. Trust chain doesn't apply.
    {error, station_mri_self_rooted};
parse_realm_id(Mri) when is_binary(Mri) ->
    case macula_mri:parse(Mri) of
        {ok, #{realm := Realm}} -> {ok, Realm};
        _                       -> {error, malformed_mri}
    end;
parse_realm_id(_) ->
    {error, malformed_mri}.

derive_leaf_storage_key(_Mri, Key, _LeafType) when is_binary(Key),
                                                    byte_size(Key) =:= 32 ->
    {ok, Key};
derive_leaf_storage_key(_Mri, undefined, _LeafType) ->
    %% Phase 1.4 doesn't auto-derive yet; resolve_mri (Phase 1.5)
    %% will pass an explicit storage key. Surfacing as a typed
    %% error rather than silently failing.
    {error, leaf_storage_key_required}.

find_opts(Opts) when is_map(Opts) ->
    maps:with([max_attempts, retry_delay_ms, total_timeout_ms,
               find_fn], Opts);
find_opts(_) ->
    #{}.

default_opts() ->
    #{grace_window_ms => application:get_env(resolve_mesh_names,
                                              trust_chain_grace_window_ms,
                                              300000)}.

sha256(Bin) ->
    crypto:hash(sha256, Bin).

%%====================================================================
%% gen_server callbacks (passive worker; see lookup_via_dht for
%% the same idiom — registered name placeholder for supervision +
%% future telemetry).
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{}}.
handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
