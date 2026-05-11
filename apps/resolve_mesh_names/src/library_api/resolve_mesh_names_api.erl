%%% @doc Public library API for resolve_mesh_names.
%%%
%%% This is the SINGLE module every consumer (Tier-2 wire bridges,
%%% the daemon REST API, the TUI naming browser) imports from this
%%% slice. No other internals are stable for cross-slice consumption.
%%%
%%% Contract documented in PLAN_RESOLVE_MESH_NAMES_PART1 §3 and
%%% docs/API_CONTRACT.md.
%%%
%%% Phase 0: every function delegates to its desk's stub, which
%%% returns `{error, X_not_yet_implemented}'. Phase 1 implementations
%%% replace the stubs without touching this module's signatures.
%%% @end
-module(resolve_mesh_names_api).

-export([
    resolve/2,
    resolve/3,
    watch/3,
    unwatch/1,
    describe/2,
    describe/3,
    verify_trust_chain/3,
    verify_trust_chain/5,
    backlinks/2,
    refresh/2,
    refresh/3
]).

-type pool()       :: term().               %% macula:pool() — opaque
-type mri()        :: binary().
-type leaf_type()  :: station_endpoint
                    | address_pubkey_map
                    | procedure_advertisement
                    | hosted_address_map.
-type sub_handle() :: reference().

-export_type([pool/0, mri/0, leaf_type/0, sub_handle/0]).

%% @doc Resolve an MRI to its current verified record(s). See
%% PLAN_RESOLVE_MESH_NAMES_PART1 §3.2.
-spec resolve(pool(), mri()) -> {ok, [map()]} | {error, atom() | tuple()}.
resolve(Pool, Mri) -> resolve_mri:resolve(Pool, Mri).

%% @doc Resolve with options (find_fn for tests, now_ms, max_attempts).
-spec resolve(pool(), mri(), map()) -> {ok, [map()]} | {error, atom() | tuple()}.
resolve(Pool, Mri, Opts) -> resolve_mri:resolve(Pool, Mri, Opts).

%% @doc Subscribe to changes for an MRI. The caller's mailbox
%% receives messages of the shape:
%%
%%   `{resolve_mesh_names, sub_handle(), record_changed,    verified_record()}'
%%   `{resolve_mesh_names, sub_handle(), record_tombstoned, mri()}'
%%   `{resolve_mesh_names, sub_handle(), trust_chain_lost,  mri(), reason()}'
-spec watch(pool(), mri(), pid()) -> {ok, sub_handle()} | {error, atom()}.
watch(Pool, Mri, Pid) -> watch_mri:watch(Pool, Mri, Pid).

%% @doc Cancel a subscription. Idempotent.
-spec unwatch(sub_handle()) -> ok.
unwatch(Handle) -> watch_mri:unwatch(Handle).

%% @doc Composite query: records + endorsements + backlinks +
%% consensus signal in a single call.
-spec describe(pool(), mri()) -> {ok, map()} | {error, atom() | tuple()}.
describe(Pool, Mri) -> describe_mri:describe(Pool, Mri).

%% @doc Composite query with options.
-spec describe(pool(), mri(), map()) -> {ok, map()} | {error, atom() | tuple()}.
describe(Pool, Mri, Opts) -> describe_mri:describe(Pool, Mri, Opts).

%% @doc Walk the 5-link trust chain explicitly. Used by resolve/2
%% internally and by operator CLI tooling.
-spec verify_trust_chain(pool(), mri(), leaf_type()) ->
    {ok, map()} | {error, atom()}.
verify_trust_chain(Pool, Mri, LeafType) ->
    verify_trust_chain:verify(Pool, Mri, LeafType).

%% @doc Walk the chain with an explicit leaf storage key + options.
-spec verify_trust_chain(pool(), mri(), binary() | undefined, atom(), map()) ->
    {ok, map()} | {error, atom()}.
verify_trust_chain(Pool, Mri, LeafKey, LeafType, Opts) ->
    verify_trust_chain:verify(Pool, Mri, LeafKey, LeafType, Opts).

%% @doc Reverse-direction query. Returns endorsements and other
%% links pointing AT this MRI.
-spec backlinks(pool(), mri()) -> {ok, [map()]} | {error, atom()}.
backlinks(Pool, Mri) -> backlinks:backlinks(Pool, Mri).

%% @doc Force-refresh: invalidate cached entry for an MRI and
%% re-resolve. Used by operator CLI and recovery from suspected
%% stale state.
-spec refresh(pool(), mri()) -> {ok, [map()]} | {error, atom() | tuple()}.
refresh(Pool, Mri) -> resolve_mri:refresh(Pool, Mri).

%% @doc Force-refresh with options.
-spec refresh(pool(), mri(), map()) -> {ok, [map()]} | {error, atom() | tuple()}.
refresh(Pool, Mri, Opts) -> resolve_mri:refresh(Pool, Mri, Opts).
