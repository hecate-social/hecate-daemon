%%% @doc Negative (NXDOMAIN / NODATA) cache. Only entries backed by
%%% a signed `coverage_proof' record (NSEC analogue) qualify for
%%% negative caching — without one, missing names emit
%%% SERVFAIL+EDE("coverage_unknown") and do NOT get cached.
%%%
%%% Phase 0: scaffold. Phase 2 wires this up — `coverage_proof'
%%% record-type spec PR has to land in macula-io/macula first.
%%% Until then this gen_server holds an empty ETS and lookup
%%% always returns miss.
%%% @end
-module(cache_negative).
-behaviour(gen_server).

-export([start_link/0, lookup/2, insert/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, serve_dns_cache_negative).

%% @doc Look up a cached negative answer for `(QName, QType)'.
-spec lookup(binary(), atom()) -> {ok, term()} | miss.
lookup(_QName, _QType) -> miss.

%% @doc Insert a coverage-proof-backed negative entry.
-spec insert(binary(), atom(), term()) -> ok.
insert(_QName, _QType, _Entry) -> ok.

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
