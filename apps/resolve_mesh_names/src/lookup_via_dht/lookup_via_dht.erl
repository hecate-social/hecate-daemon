%%% @doc lookup_via_dht: thin wrapper over `macula:find_record/2'
%%% with poll-with-retry to compensate for the documented ~60%
%%% per-attempt cross-station flake (see
%%% `macula-internal/macula-station/docs/DHT_FIND_FLAKE_ATTEMPT.md').
%%% Two retries bring the effective hit rate to ~94%; three to ~98%.
%%% We don't push higher — diminishing returns and tail latency
%%% start dominating. The full fix needs multi-round Kademlia
%%% iterative in the substrate (substrate Phase 4+).
%%%
%%% Concurrency: every call routes through `lookup_dedup' so
%%% multiple concurrent finds for the same storage key piggyback
%%% on a single DHT call.
%%%
%%% The macula SDK enforces a 5000 ms internal timeout per
%%% `find_record/2' call. We don't try to override that; our
%%% retry just iterates up to N attempts on `not_found' / `timeout'
%%% replies (the substrate-flake error shapes). Other errors
%%% (signature failure, malformed record, etc.) are returned
%%% immediately — they're not transient.
%%%
%%% The gen_server itself holds no state; it exists so the desk
%%% has a registered worker for supervision + future telemetry.
%%% The public API (`find/2,3') is a static module function.
%%% @end
-module(lookup_via_dht).
-behaviour(gen_server).

-export([start_link/0, find/2, find/3]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2,
         terminate/2, code_change/3]).

%% Errors that are worth retrying — the substrate flake surfaces
%% as one of these.
-define(RETRYABLE_ERRORS, [not_found, timeout]).

%%====================================================================
%% Public API
%%====================================================================

%% @equiv find(Pool, Key, #{})
-spec find(Pool :: pid(), Key :: binary()) ->
    {ok, map()} | {error, atom()}.
find(Pool, Key) ->
    find(Pool, Key, #{}).

%% @doc Look up a record by storage key in the DHT, with retry +
%% in-flight de-dup. Returns the raw record map (no signature
%% verification — that lives in `verify_trust_chain').
%%
%% Opts:
%%   `max_attempts'         pos integer (default: app env
%%                          `dht_lookup_retry_attempts', 3)
%%   `retry_delay_ms'       backoff between retries (default: 50)
%%   `total_timeout_ms'     overall deadline including dedup wait
%%                          (default: app env, 20_000)
%%   `find_fn'              fun for dependency injection in tests:
%%                          `fun(Pool, Key) -> {ok, map()} | {error, atom()}'
%%                          (default: `fun macula:find_record/2')
-spec find(Pool :: pid(), Key :: binary(), Opts :: map()) ->
    {ok, map()} | {error, atom()}.
find(Pool, Key, Opts) when is_binary(Key) ->
    Caller = self(),
    case lookup_dedup:claim_or_wait(Key, Caller) of
        {claimed, Ref} ->
            Result = do_lookup_with_retry(Pool, Key, Opts),
            lookup_dedup:broadcast_result(Key, Result),
            collect_result(Ref, Opts);
        {waiting, Ref} ->
            collect_result(Ref, Opts)
    end.

%%====================================================================
%% Internal — retry loop
%%====================================================================

do_lookup_with_retry(Pool, Key, Opts) ->
    MaxAttempts = max_attempts(Opts),
    DelayMs     = retry_delay_ms(Opts),
    FindFn      = find_fn(Opts),
    do_attempt(Pool, Key, FindFn, DelayMs, MaxAttempts, undefined).

do_attempt(_Pool, _Key, _FindFn, _Delay, 0, LastErr) ->
    {error, LastErr};
do_attempt(Pool, Key, FindFn, Delay, AttemptsLeft, _PrevErr) ->
    case FindFn(Pool, Key) of
        {ok, _} = Ok ->
            Ok;
        {error, Reason} = Err ->
            case lists:member(Reason, ?RETRYABLE_ERRORS) of
                true when AttemptsLeft > 1 ->
                    timer:sleep(Delay),
                    do_attempt(Pool, Key, FindFn, Delay, AttemptsLeft - 1, Reason);
                true ->
                    %% Exhausted retries; surface the last error.
                    Err;
                false ->
                    %% Non-substrate error (sig fail, malformed,
                    %% etc.) — never retry; surface immediately.
                    Err
            end
    end.

collect_result(Ref, Opts) ->
    Timeout = total_timeout(Opts),
    receive
        {lookup_result, Ref, Result} -> Result
    after Timeout ->
        {error, lookup_dedup_timeout}
    end.

%%====================================================================
%% Opts helpers
%%====================================================================

max_attempts(#{max_attempts := N}) when is_integer(N), N >= 1 -> N;
max_attempts(_) ->
    application:get_env(resolve_mesh_names, dht_lookup_retry_attempts, 3).

retry_delay_ms(#{retry_delay_ms := D}) when is_integer(D), D >= 0 -> D;
retry_delay_ms(_) ->
    application:get_env(resolve_mesh_names, dht_lookup_retry_delay_ms, 50).

find_fn(#{find_fn := F}) when is_function(F, 2) -> F;
find_fn(_) ->
    fun macula:find_record/2.

total_timeout(#{total_timeout_ms := T}) when is_integer(T), T >= 0 -> T;
total_timeout(_) ->
    application:get_env(resolve_mesh_names, total_lookup_timeout_ms, 20000).

%%====================================================================
%% gen_server callbacks (passive worker)
%%====================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, #{}}.

handle_call(_Req, _From, S) -> {reply, {error, not_yet_implemented}, S}.
handle_cast(_Msg, S) -> {noreply, S}.
handle_info(_Info, S) -> {noreply, S}.
terminate(_Reason, _S) -> ok.
code_change(_Old, S, _Ex) -> {ok, S}.
