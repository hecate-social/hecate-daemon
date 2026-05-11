%%% @doc lookup_dedup: in-flight ETS de-dup registry for DHT
%%% lookups (PLAN_RESOLVE_MESH_NAMES_PART1 §6.4).
%%%
%%% Two callers issuing find/3 for the same storage key
%%% concurrently must result in ONE DHT call, not two — otherwise
%%% under cache-cold conditions every cache miss would
%%% thundering-herd on the DHT.
%%%
%%% Protocol:
%%%   1. Caller invokes `claim_or_wait(Key, self())'.
%%%   2. If no one is in flight for `Key': caller becomes the owner.
%%%      Reply is `{claimed, Ref}'. Owner does the actual lookup.
%%%   3. If someone is already in flight for `Key': caller becomes
%%%      a waiter. Reply is `{waiting, Ref}'. Waiter blocks on
%%%      receive `{lookup_result, Ref, Result}'.
%%%   4. Owner calls `broadcast_result(Key, Result)' on completion;
%%%      every registered party (owner + waiters) receives the
%%%      result message and the dedup entry is evicted.
%%%
%%% The owner is itself registered with a Ref so it consumes the
%%% same broadcast as the waiters — keeps the API uniform.
%%%
%%% Race-safe via gen_server serialisation; ETS state lets us
%%% inspect the in-flight table for diagnostics without taking
%%% a lock.
%%% @end
-module(lookup_dedup).
-behaviour(gen_server).

-export([start_link/0, claim_or_wait/2, broadcast_result/2,
         in_flight/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

-define(TABLE, resolve_mesh_names_lookup_dedup).

%% @doc Either claim ownership of a lookup for `Key', or register
%% as a waiter on an in-flight lookup. The reply tag identifies
%% the role; the `Ref' is the message-tag for the eventual
%% `{lookup_result, Ref, Result}' broadcast.
-spec claim_or_wait(Key :: binary(), Caller :: pid()) ->
    {claimed, reference()} | {waiting, reference()}.
claim_or_wait(Key, Caller) ->
    gen_server:call(?MODULE, {claim_or_wait, Key, Caller}).

%% @doc Owner-only: announce the result of the in-flight lookup
%% for `Key'. Every registered party (owner + waiters) receives
%% `{lookup_result, Ref, Result}' in their mailbox; the in-flight
%% entry is evicted.
-spec broadcast_result(Key :: binary(), Result :: term()) -> ok.
broadcast_result(Key, Result) ->
    gen_server:cast(?MODULE, {broadcast_result, Key, Result}).

%% @doc Diagnostic: how many keys are currently in flight.
-spec in_flight() -> non_neg_integer().
in_flight() ->
    case ets:info(?TABLE, size) of
        undefined -> 0;
        N         -> N
    end.

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [named_table, protected, set,
                              {read_concurrency, true}]),
    {ok, #{}}.

handle_call({claim_or_wait, Key, Caller}, _From, State) ->
    Ref = make_ref(),
    Entry = {Caller, Ref},
    case ets:lookup(?TABLE, Key) of
        [] ->
            ets:insert(?TABLE, {Key, [Entry]}),
            {reply, {claimed, Ref}, State};
        [{Key, Existing}] ->
            ets:insert(?TABLE, {Key, [Entry | Existing]}),
            {reply, {waiting, Ref}, State}
    end;
handle_call(_Req, _From, S) ->
    {reply, {error, not_yet_implemented}, S}.

handle_cast({broadcast_result, Key, Result}, State) ->
    case ets:take(?TABLE, Key) of
        [{Key, Parties}] ->
            lists:foreach(fun({Pid, Ref}) ->
                Pid ! {lookup_result, Ref, Result}
            end, Parties);
        [] ->
            %% No one waiting (entry already evicted, or never
            %% claimed). Silently drop — broadcast is fire-and-forget.
            ok
    end,
    {noreply, State};
handle_cast(_Msg, S) ->
    {noreply, S}.

handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
