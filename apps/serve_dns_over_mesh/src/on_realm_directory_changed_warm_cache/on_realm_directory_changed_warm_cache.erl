%%% @doc Process Manager — when a `realm_directory' record is
%%% observed (= a realm's trust delegates / coverage proof pointer
%%% changed), pre-warm the cache for the realm's hot names so the
%%% next query for them doesn't pay full DHT-walk latency.
%%%
%%% Phase 0: scaffold. Phase 1 will: subscribe to records of type
%%% 0x03 (`realm_directory'), on observation derive the realm_id,
%%% enumerate the realm's `_trust' / `_directory' / common app
%%% names, kick off `lookup_record_in_dht' for each.
%%% @end
-module(on_realm_directory_changed_warm_cache).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) -> {ok, #{phase => scaffold, sub_refs => []}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
