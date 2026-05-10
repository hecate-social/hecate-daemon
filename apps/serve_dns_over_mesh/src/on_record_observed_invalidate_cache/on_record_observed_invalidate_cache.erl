%%% @doc Process Manager — reacts to record-observed events on the
%%% local DHT and invalidates the corresponding `cache_positive'
%%% entries.
%%%
%%% Subscribes via `macula:subscribe_records/3' (now working
%%% end-to-end as of macula 4.2.9 + macula-station's
%%% `_dht.records.<type>.stored' publication, see
%%% macula-station/docs/SUBSCRIBE_RECORDS_GAP.md). Every observed
%%% record arrives at the callback; the PM derives any cache
%%% entries that depend on this record's storage_key (via the
%%% MRI/qname mapping) and calls `cache_positive:invalidate/2'.
%%%
%%% Phase 0: scaffold. The gen_server boots without subscribing.
%%% Phase 1 wires up the subscription + invalidation logic.
%%% @end
-module(on_record_observed_invalidate_cache).
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
