%%% @doc In-flight de-dup ETS owner for `lookup_record_in_dht'.
%%%
%%% Phase 0: scaffold. Owns a named ETS table that future code uses
%%% to register {StorageKey, WalkerPid, [WaiterPid]} entries. Boots
%%% with the table created so the dedup logic in
%%% `lookup_record_in_dht' (Phase 1) can write/read it without a
%%% race against table creation.
%%% @end
-module(lookup_record_dedup).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, serve_dns_lookup_dedup).

start_link() -> gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [named_table, public, set,
                              {read_concurrency, true},
                              {write_concurrency, true}]),
    {ok, #{phase => scaffold, table => ?TABLE}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S)        -> {noreply, S}.
handle_info(_Info, S)       -> {noreply, S}.
terminate(_Reason, _S)      -> ok.
code_change(_Old, S, _Ex)   -> {ok, S}.
