%%% @doc trust_anchors desk: foundation seed registry. Maps
%%% `realm_id() → foundation_pubkey()'. The L0 layer of the
%%% 5-link trust chain (PLAN_RESOLVE_MESH_NAMES_PART1 §5.1).
%%%
%%% Without an entry for a realm here, `verify_trust_chain' has
%%% no anchor to start from and returns `{error, no_trust_root}'.
%%%
%%% Source order at boot (PART1 §5.6):
%%%   1. compiled-in seeds for canonical realms — read from
%%%      app env `compiled_in_seeds' (a list of `{RealmId, FoundationPubkey}'
%%%      tuples). Convention: ship `io.macula' and `io.beamcampus'
%%%      seeds in the daemon's release config so it boots usable.
%%%   2. on-disk file load — Phase 1.3+, deferred. The file
%%%      format will be CBOR-encoded list of seeds; trust is
%%%      provenance-based (out-of-band sealed file), not signature-
%%%      based (chicken-and-egg with the foundation_pubkey we're
%%%      learning).
%%%   3. runtime imports via `hecate names trust import <seed.cbor>' — Phase 1.3+
%%%   4. LAN seed gossip via `discover_lan' — opt-in, Phase 1.3+
%%%
%%% Never pulls seeds over plain HTTP / unauthenticated channels.
%%%
%%% This module owns the named ETS table
%%% `resolve_mesh_names_trust_anchors'. Reads are concurrent
%%% (`read_concurrency'); writes serialise through this gen_server
%%% so concurrent put/remove can't race.
%%% @end
-module(trust_anchors).
-behaviour(gen_server).

-export([start_link/0, get/1, put/2, remove/1, list/0, count/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, resolve_mesh_names_trust_anchors).

%%====================================================================
%% Public API
%%====================================================================

%% @doc Look up the foundation pubkey trusted to sign FRTL for a
%% given realm. Returns `{error, no_trust_root}' when the daemon
%% has no anchor for `RealmId'.
-spec get(RealmId :: binary()) -> {ok, binary()} | {error, no_trust_root}.
get(RealmId) when is_binary(RealmId) ->
    case ets:lookup(?TABLE, RealmId) of
        []                -> {error, no_trust_root};
        [{_, FoundPubKey}] -> {ok, FoundPubKey}
    end.

%% @doc Install (or replace) a foundation seed for a realm.
%% Idempotent — same `(RealmId, Pubkey)' pair twice is a no-op.
%% Replacing a different pubkey for an existing realm overwrites
%% (operator-led rotation).
-spec put(RealmId :: binary(), FoundationPubkey :: binary()) ->
    ok | {error, atom()}.
put(RealmId, FoundationPubkey)
  when is_binary(RealmId), is_binary(FoundationPubkey),
       byte_size(FoundationPubkey) =:= 32 ->
    gen_server:call(?MODULE, {put, RealmId, FoundationPubkey});
put(_, _) ->
    {error, invalid_seed}.

%% @doc Remove a foundation seed (operator-led; rare).
-spec remove(RealmId :: binary()) -> ok.
remove(RealmId) when is_binary(RealmId) ->
    gen_server:call(?MODULE, {remove, RealmId}).

%% @doc List every realm we have a trust anchor for, with its
%% foundation pubkey. Used by `hecate names trust list'.
-spec list() -> [{binary(), binary()}].
list() ->
    ets:tab2list(?TABLE).

%% @doc Diagnostic: how many anchors are installed.
-spec count() -> non_neg_integer().
count() ->
    ets:info(?TABLE, size).

%%====================================================================
%% gen_server callbacks
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [named_table, protected, set,
                              {read_concurrency, true}]),
    bootstrap_compiled_in_seeds(),
    {ok, #{}}.

%% Read app env at boot; install each seed via direct ETS insert
%% (we're inside init/1, no gen_server messages yet).
bootstrap_compiled_in_seeds() ->
    Seeds = application:get_env(resolve_mesh_names, compiled_in_seeds, []),
    lists:foreach(fun
        ({RealmId, FoundationPubkey})
          when is_binary(RealmId), is_binary(FoundationPubkey),
               byte_size(FoundationPubkey) =:= 32 ->
            ets:insert(?TABLE, {RealmId, FoundationPubkey});
        (Other) ->
            logger:warning("trust_anchors: skipping malformed compiled-in seed ~p", [Other])
    end, Seeds).

handle_call({put, RealmId, FoundationPubkey}, _From, State) ->
    ets:insert(?TABLE, {RealmId, FoundationPubkey}),
    {reply, ok, State};
handle_call({remove, RealmId}, _From, State) ->
    ets:delete(?TABLE, RealmId),
    {reply, ok, State};
handle_call(_Req, _From, State) ->
    {reply, {error, not_yet_implemented}, State}.

handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
