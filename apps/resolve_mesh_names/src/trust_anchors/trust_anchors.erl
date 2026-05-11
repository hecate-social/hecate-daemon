%%% @doc trust_anchors desk: foundation seed registry.
%%%
%%% Owns the ETS table mapping `realm_id → foundation_pubkey'.
%%% Source order (PLAN PART1 §5.6):
%%%   - compiled-in seeds for canonical realms (`io.macula', `io.beamcampus')
%%%   - on-disk file (`~/.hecate/trust_anchors.cbor', signed import)
%%%   - runtime imports via `hecate names trust import <seed.cbor>'
%%%   - LAN seed gossip (opt-in; comes from `discover_lan' slice)
%%%
%%% Never pulls seeds over plain HTTP / unauthenticated channels.
%%%
%%% Phase 0: scaffold; ETS table created; get/put functions stub.
%%% @end
-module(trust_anchors).
-behaviour(gen_server).

-export([start_link/0, get/1, put/2, list/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, resolve_mesh_names_trust_anchors).

%% @doc Look up the foundation_pubkey trusted to sign FRTL for a
%% given realm.
-spec get(RealmId :: binary()) -> {ok, binary()} | {error, atom()}.
get(_RealmId) -> {error, no_trust_root}.

%% @doc Install (or replace) a foundation seed for a realm. Operator
%% command; signed seed file expected.
-spec put(RealmId :: binary(), FoundationPubkey :: binary()) -> ok.
put(_RealmId, _FoundationPubkey) -> ok.

%% @doc List every realm we have a trust anchor for.
-spec list() -> [{binary(), binary()}].
list() -> [].

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [named_table, public, set,
                              {read_concurrency, true}]),
    {ok, #{phase => scaffold, table => ?TABLE}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
