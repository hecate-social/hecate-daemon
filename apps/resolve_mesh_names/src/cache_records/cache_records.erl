%%% @doc cache_records: ETS owner for the 5-layer cache
%%% (PLAN_RESOLVE_MESH_NAMES_PART1 §5.3).
%%%
%%% Layers (each a separate named ETS table; reads concurrent,
%%% writes serialised through this gen_server):
%%%   L1: `(realm_id) → realm_root_pubkey'   from FRTL
%%%   L2: `realm_directory' per realm
%%%   L3: `realm_member_endorsement' per (realm, path)
%%%   L4: leaf record per (mri, record_type)
%%%   L5: composite verified result per mri
%%%
%%% Each cached value carries `expires_at' (epoch ms) and
%%% `version' (UUIDv7 or fallback monotonic int) so the
%%% TTL sweep can evict on time and the invalidate desk can
%%% detect stale-vs-fresh on cascades.
%%%
%%% Cache invariants enforced here (PART1 §5.3):
%%%   - Every entry was verified at write time. No signature, no
%%%     write — caller's responsibility (verify_trust_chain calls
%%%     put/5 only after a successful chain walk).
%%%   - get/2 returns `miss' for entries past `expires_at' AND
%%%     evicts them lazily.
%%%   - put/5 is idempotent for `(key, version)' pairs.
%%%
%%% Push invalidation + cascade live in `cache_invalidate'; this
%%% module owns the data + low-level reads/writes only.
%%% @end
-module(cache_records).
-behaviour(gen_server).

-export([start_link/0, get/2, put/5, delete/2, all_keys/1, size/1,
         layer_table/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(L1_TABLE, resolve_mesh_names_cache_l1_realm_pubkeys).
-define(L2_TABLE, resolve_mesh_names_cache_l2_realm_directories).
-define(L3_TABLE, resolve_mesh_names_cache_l3_endorsements).
-define(L4_TABLE, resolve_mesh_names_cache_l4_leaf_records).
-define(L5_TABLE, resolve_mesh_names_cache_l5_verified_composites).

-type layer() :: l1 | l2 | l3 | l4 | l5.
-type version() :: binary() | non_neg_integer().
-type expires_at() :: integer().              %% epoch ms

-export_type([layer/0, version/0, expires_at/0]).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Get a cached entry. Returns `{ok, Value, ExpiresAt}' on
%% fresh hit, `miss' on miss OR on stale-but-not-yet-swept entry
%% (also evicts the stale entry as a side effect).
-spec get(Layer :: layer(), Key :: term()) ->
    {ok, term(), expires_at()} | miss.
get(Layer, Key) ->
    Table = layer_table(Layer),
    case ets:lookup(Table, Key) of
        [] ->
            miss;
        [{_, {Value, ExpiresAt, _Version}}] ->
            case ExpiresAt > now_ms() of
                true  -> {ok, Value, ExpiresAt};
                false ->
                    %% Lazy eviction; sweep would catch it eventually
                    %% but we may as well drop it now.
                    gen_server:cast(?MODULE, {evict_stale, Layer, Key}),
                    miss
            end
    end.

%% @doc Insert a verified entry. Last-write-wins for now;
%% UUIDv7 monotonicity check is Phase 1.5+ once push events
%% arrive with stable versions.
-spec put(Layer :: layer(),
          Key :: term(),
          Value :: term(),
          ExpiresAt :: expires_at(),
          Version :: version()) -> ok.
put(Layer, Key, Value, ExpiresAt, Version)
  when ExpiresAt > 0 ->
    gen_server:call(?MODULE, {put, Layer, Key, Value, ExpiresAt, Version}).

%% @doc Delete an entry. Idempotent.
-spec delete(Layer :: layer(), Key :: term()) -> ok.
delete(Layer, Key) ->
    gen_server:call(?MODULE, {delete, Layer, Key}).

%% @doc List every key in a layer. Used by `cache_invalidate'
%% for cascade scans + `cache_ttl_sweep' for eviction.
-spec all_keys(Layer :: layer()) -> [term()].
all_keys(Layer) ->
    Table = layer_table(Layer),
    ets:foldl(fun({K, _}, Acc) -> [K | Acc] end, [], Table).

%% @doc Diagnostic: current size of a layer.
-spec size(Layer :: layer()) -> non_neg_integer().
size(Layer) ->
    case ets:info(layer_table(Layer), size) of
        undefined -> 0;
        N         -> N
    end.

%% @doc Return the named ETS table atom for a layer. Used by
%% sibling cache_* modules that need direct ETS access (cascade
%% scans, TTL sweeps).
-spec layer_table(layer()) -> atom().
layer_table(l1) -> ?L1_TABLE;
layer_table(l2) -> ?L2_TABLE;
layer_table(l3) -> ?L3_TABLE;
layer_table(l4) -> ?L4_TABLE;
layer_table(l5) -> ?L5_TABLE.

%%====================================================================
%% gen_server callbacks
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    create_table(?L1_TABLE),
    create_table(?L2_TABLE),
    create_table(?L3_TABLE),
    create_table(?L4_TABLE),
    create_table(?L5_TABLE),
    {ok, #{}}.

create_table(Name) ->
    catch ets:delete(Name),
    Name = ets:new(Name, [named_table, protected, set,
                          {read_concurrency, true}]).

handle_call({put, Layer, Key, Value, ExpiresAt, Version}, _From, State) ->
    Table = layer_table(Layer),
    ets:insert(Table, {Key, {Value, ExpiresAt, Version}}),
    {reply, ok, State};
handle_call({delete, Layer, Key}, _From, State) ->
    Table = layer_table(Layer),
    ets:delete(Table, Key),
    {reply, ok, State};
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast({evict_stale, Layer, Key}, State) ->
    Table = layer_table(Layer),
    %% Race-tolerant: only delete if still stale at handle time.
    case ets:lookup(Table, Key) of
        [{_, {_, ExpiresAt, _}}] when ExpiresAt =< 0 -> ets:delete(Table, Key);
        [{_, {_, ExpiresAt, _}}] ->
            case ExpiresAt > now_ms() of
                true  -> ok;            %% became fresh again, leave it
                false -> ets:delete(Table, Key)
            end;
        [] -> ok
    end,
    {noreply, State};
handle_cast(_Msg, S) -> {noreply, S}.

handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.

%%====================================================================
%% Helpers
%%====================================================================

now_ms() ->
    erlang:system_time(millisecond).
