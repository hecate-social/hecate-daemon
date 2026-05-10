%%% @doc Positive (resolved-RRset) cache. Keyed by `(qname, qtype)';
%%% TTL is `min(record.expires_at - now, configured max_cache_ttl,
%%% configured min_cache_ttl_floor)'.
%%%
%%% Phase 0: scaffold. Owns a named ETS table; lookup/insert
%%% functions return `{error, not_yet_implemented}' (Phase 1 wires
%%% them up). Cache invalidation is event-driven via the
%%% `on_record_observed_invalidate_cache' PM.
%%% @end
-module(cache_positive).
-behaviour(gen_server).

-export([start_link/0, lookup/2, insert/3, invalidate/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, serve_dns_cache_positive).

%% @doc Look up a cached RRset by `(QName, QType)'. Returns
%% `{ok, Entry}' on hit (where Entry is the RRset + TTL/expiry
%% metadata) or `miss' on miss.
-spec lookup(binary(), atom()) -> {ok, term()} | miss.
lookup(_QName, _QType) -> miss.

%% @doc Insert an RRset entry under `(QName, QType)'.
-spec insert(binary(), atom(), term()) -> ok.
insert(_QName, _QType, _Entry) -> ok.

%% @doc Invalidate the cache entry for `(QName, QType)'.
-spec invalidate(binary(), atom()) -> ok.
invalidate(_QName, _QType) -> ok.

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
