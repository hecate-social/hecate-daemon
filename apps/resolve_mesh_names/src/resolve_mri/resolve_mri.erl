%%% @doc resolve_mri desk: single-shot MRI resolution — the engine
%%% behind `library_api:resolve/2'.
%%%
%%% Pipeline (PLAN_RESOLVE_MESH_NAMES_PART1 §7.1):
%%%   1. classify the MRI (type, realm, path)
%%%   2. cache_records:get(L5, Mri) → hit + fresh? return verified
%%%   3. else dispatch by MRI type:
%%%      - `station' → SELF-ROOTED path: fetch station_endpoint by
%%%        sha256("station_endpoint" || pubkey), verify it's
%%%        self-signed (envelope key == the pubkey from the MRI).
%%%        No realm trust chain — stations are their own root.
%%%      - `proc'    → realm trust chain: storage key derived from
%%%        the procedure URI (the MRI string), leaf type
%%%        procedure_advertisement.
%%%      - everything else (user/app/service/device/...) → not yet
%%%        resolvable: there's no deterministic MRI → storage-key
%%%        mapping for these without an intermediate index record.
%%%        Surfaces `{error, {not_resolvable_yet, Type}}'. Closing
%%%        this gap needs either a realm-scoped name→pubkey index
%%%        (a macula 4.4.0 candidate) or per-type conventions that
%%%        aren't pinned down yet.
%%%   4. cache_records:put(L5, Mri, [verified_record])
%%%
%%% The gen_server holds no state; it's a registered worker for
%%% supervision + future telemetry. The public API is static.
%%% @end
-module(resolve_mri).
-behaviour(gen_server).

-export([start_link/0, resolve/2, resolve/3, refresh/2, refresh/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(STORAGE_DOMAIN_STATION_ENDPOINT, <<"station_endpoint">>).

%% Default L5 TTL when the resolution path doesn't carry a record-
%% level expires_at (e.g., the chain-derived verified_record bundles).
-define(DEFAULT_L5_TTL_MS, 60000).

%%====================================================================
%% Public API
%%====================================================================

%% @equiv resolve(Pool, Mri, #{})
-spec resolve(Pool :: pid(), Mri :: binary()) ->
    {ok, [map()]} | {error, atom() | tuple()}.
resolve(Pool, Mri) ->
    resolve(Pool, Mri, #{}).

%% @doc Resolve an MRI to its current verified record(s). Checks
%% the L5 cache first; on miss, walks the appropriate resolution
%% path and populates the cache.
%%
%% Opts:
%%   `find_fn'      dependency-injected DHT lookup (test DI;
%%                  forwarded to lookup_via_dht / verify_trust_chain)
%%   `now_ms'       clock override
%%   `max_attempts' DHT retries
-spec resolve(Pool :: pid(), Mri :: binary(), Opts :: map()) ->
    {ok, [map()]} | {error, atom() | tuple()}.
resolve(Pool, Mri, Opts) ->
    case cache_records:get(l5, Mri) of
        {ok, VerifiedRecords, _ExpiresAt} when is_list(VerifiedRecords) ->
            {ok, VerifiedRecords};
        miss ->
            do_resolve(Pool, Mri, Opts)
    end.

%% @equiv refresh(Pool, Mri, #{})
-spec refresh(Pool :: pid(), Mri :: binary()) ->
    {ok, [map()]} | {error, atom() | tuple()}.
refresh(Pool, Mri) ->
    refresh(Pool, Mri, #{}).

%% @doc Force-refresh: invalidate the L4 + L5 cache entries for an
%% MRI, then re-resolve from scratch.
-spec refresh(Pool :: pid(), Mri :: binary(), Opts :: map()) ->
    {ok, [map()]} | {error, atom() | tuple()}.
refresh(Pool, Mri, Opts) ->
    ok = cache_invalidate:by_mri(Mri),
    do_resolve(Pool, Mri, Opts).

%%====================================================================
%% Resolution pipeline
%%====================================================================

do_resolve(Pool, Mri, Opts) ->
    case classify_mri(Mri) of
        {station, Pubkey} ->
            resolve_station(Pool, Mri, Pubkey, Opts);
        {proc, _Realm, _Path} ->
            resolve_proc(Pool, Mri, Opts);
        {Type, _Realm, _Path} ->
            {error, {not_resolvable_yet, Type}};
        {error, _} = E ->
            E
    end.

classify_mri(<<"mri:station:", Z32/binary>>) ->
    case macula_z32:decode(Z32) of
        {ok, <<Pubkey:32/binary>>} -> {station, Pubkey};
        {ok, _Other}               -> {error, malformed_station_mri};
        {error, _}                 -> {error, malformed_station_mri}
    end;
classify_mri(Mri) when is_binary(Mri) ->
    case macula_mri:parse(Mri) of
        {ok, #{type := Type, realm := Realm, path := Path}} ->
            {Type, Realm, Path};
        _ ->
            {error, malformed_mri}
    end;
classify_mri(_) ->
    {error, malformed_mri}.

%%--------------------------------------------------------------------
%% Station MRIs — self-rooted, no realm trust chain.
%%--------------------------------------------------------------------

resolve_station(Pool, Mri, Pubkey, Opts) ->
    StorageKey = crypto:hash(sha256,
                             <<?STORAGE_DOMAIN_STATION_ENDPOINT/binary,
                               Pubkey/binary>>),
    case lookup_via_dht:find(Pool, StorageKey, find_opts(Opts)) of
        {ok, Record} ->
            case verify_self_signed(Record, Pubkey) of
                ok ->
                    NowMs = now_ms(Opts),
                    VR = build_verified_record(Record, Mri, station_endpoint,
                                               Pubkey, self_rooted, NowMs),
                    cache_l4(Mri, station_endpoint, Record),
                    cache_l5(Mri, [VR]),
                    {ok, [VR]};
                {error, _} = E ->
                    E
            end;
        {error, _} ->
            {error, station_not_announced}
    end.

%% A self-rooted leaf: envelope key MUST equal the pubkey from the
%% MRI, and the signature must verify against that same key.
verify_self_signed(#{key := K} = Record, Pubkey) when K =:= Pubkey ->
    case macula_record:verify(Record) of
        {ok, _}    -> ok;
        {error, _} -> {error, sig_indeterminate}
    end;
verify_self_signed(#{key := _}, _) ->
    {error, sig_indeterminate};
verify_self_signed(_, _) ->
    {error, sig_indeterminate}.

%%--------------------------------------------------------------------
%% Proc MRIs — realm trust chain, leaf type procedure_advertisement.
%% Procedure URI convention: the MRI string itself (macula's
%% procedure_advertisement storage key is sha256(procedure_uri)).
%%--------------------------------------------------------------------

resolve_proc(Pool, Mri, Opts) ->
    StorageKey = crypto:hash(sha256, Mri),
    case verify_trust_chain:verify(Pool, Mri, StorageKey,
                                   procedure_advertisement, Opts) of
        {ok, VR} ->
            %% verify_trust_chain already wrote L4 + L5 for the
            %% station_endpoint leaf-type key; for proc it wrote
            %% under {Mri, procedure_advertisement}. The L5 entry
            %% it wrote holds [VR]. Return it directly.
            {ok, [VR]};
        {error, _} = E ->
            E
    end.

%%====================================================================
%% verified_record construction (matches PART1 §3.1 shape)
%%====================================================================

build_verified_record(Record, Mri, LeafType, SignerPubkey, ChainKind, NowMs) ->
    #{
        record_type   => LeafType,
        mri           => Mri,
        payload       => maps:get(payload, Record, #{}),
        signer_pubkey => SignerPubkey,
        chain         => chain_metadata(ChainKind, SignerPubkey),
        expires_at    => maps:get(expires_at, Record, 0),
        version       => maps:get(version, Record, undefined),
        observed_at   => NowMs
    }.

chain_metadata(self_rooted, Pubkey) ->
    [#{type => self_rooted, pubkey => Pubkey}];
chain_metadata(_, Pubkey) ->
    [#{type => leaf, pubkey => Pubkey}].

%%====================================================================
%% Caching helpers
%%====================================================================

cache_l4(Mri, LeafType, Record) ->
    Exp = record_expires_at(Record, ?DEFAULT_L5_TTL_MS),
    Ver = maps:get(version, Record, 0),
    cache_records:put(l4, {Mri, LeafType}, Record, Exp, Ver).

cache_l5(Mri, VerifiedRecords) ->
    Exp = erlang:system_time(millisecond) + ?DEFAULT_L5_TTL_MS,
    cache_records:put(l5, Mri, VerifiedRecords, Exp, 0).

record_expires_at(#{expires_at := EA}, _Default) when is_integer(EA), EA > 0 ->
    EA;
record_expires_at(_, Default) ->
    erlang:system_time(millisecond) + Default.

%%====================================================================
%% Opts helpers
%%====================================================================

find_opts(Opts) when is_map(Opts) ->
    maps:with([find_fn, max_attempts, retry_delay_ms, total_timeout_ms], Opts);
find_opts(_) ->
    #{}.

now_ms(#{now_ms := N}) when is_integer(N) -> N;
now_ms(_) -> erlang:system_time(millisecond).

%%====================================================================
%% gen_server callbacks (passive worker)
%%====================================================================

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{}}.
handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
