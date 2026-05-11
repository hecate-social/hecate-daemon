%%% @doc cache_records: ETS owner for the 5-layer cache (PLAN PART1
%%% §5.3).
%%%
%%% Layers (each is a separate named ETS table, public, set,
%%% read-concurrent):
%%%   L1: (realm_id) → realm_root_pubkey         from FRTL
%%%   L2: realm_directory per realm
%%%   L3: realm_member_endorsement per (realm, path)
%%%   L4: leaf record per (mri, record_type)
%%%   L5: composite verified result per mri
%%%
%%% Cache invariants (PLAN PART1 §5.3):
%%%   - every entry was verified at write time (no signature, no write)
%%%   - tombstones supersede all live cache for the same key
%%%   - UUIDv7 monotonic; newer always replaces older
%%%   - L5 derived from L1..L4 — invalidating any upstream cascades
%%%
%%% Phase 0: scaffold; ETS tables created but get/put functions stub.
%%% @end
-module(cache_records).
-behaviour(gen_server).

-export([start_link/0, get/2, put/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(L1_TABLE, resolve_mesh_names_cache_l1_realm_pubkeys).
-define(L2_TABLE, resolve_mesh_names_cache_l2_realm_directories).
-define(L3_TABLE, resolve_mesh_names_cache_l3_endorsements).
-define(L4_TABLE, resolve_mesh_names_cache_l4_leaf_records).
-define(L5_TABLE, resolve_mesh_names_cache_l5_verified_composites).

%% @doc Get a cached entry from a specific layer. Returns
%% `{ok, Entry}' on hit (entry is fresh) or `miss'.
-spec get(Layer :: l1 | l2 | l3 | l4 | l5, Key :: term()) ->
    {ok, term()} | miss.
get(_Layer, _Key) -> miss.

%% @doc Insert a verified entry into a specific layer.
-spec put(Layer :: l1 | l2 | l3 | l4 | l5, Key :: term(),
          Entry :: term()) -> ok.
put(_Layer, _Key, _Entry) -> ok.

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    create_table(?L1_TABLE),
    create_table(?L2_TABLE),
    create_table(?L3_TABLE),
    create_table(?L4_TABLE),
    create_table(?L5_TABLE),
    {ok, #{phase => scaffold,
           tables => [?L1_TABLE, ?L2_TABLE, ?L3_TABLE, ?L4_TABLE, ?L5_TABLE]}}.

create_table(Name) ->
    catch ets:delete(Name),
    Name = ets:new(Name, [named_table, public, set,
                          {read_concurrency, true}]),
    Name.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
