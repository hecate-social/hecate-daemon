%%%-------------------------------------------------------------------
%%% @doc Projection readiness tracker.
%%%
%%% After store subscriptions start, events replay asynchronously
%%% into ETS-backed projections. This module detects when replay is
%%% complete by comparing store contents against ETS table population.
%%%
%%% Logic per store:
%%%   - Store query fails → not ready (Ra cluster might still be forming)
%%%   - Store has no events → projection has nothing to do → ready
%%%   - Store has events AND ETS table has data → replay finished → ready
%%%   - Store has events BUT ETS table empty → still replaying → not ready
%%%
%%% Once all stores are ready, sets hecate_lifecycle to `running`.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_readiness).

-export([await_projections/0]).

-define(POLL_INTERVAL_MS, 250).
-define(TIMEOUT_MS, 30_000).

%% Stores and their corresponding ETS projection tables.
%% If a store has events, its ETS table must be populated before
%% we consider projections ready.
-define(STORE_PROJECTIONS, [
    {settings_store,          settings},
    {realm_memberships_store, realm_memberships},
    {licenses_store,          licenses},
    {licenses_store,          catalog},
    {plugins_store,           plugins},
    {launcher_store,          launcher_entries}
]).

%%--------------------------------------------------------------------
%% @doc Spawn background watcher that sets `running` once projections
%% have replayed all historical events (or timeout is reached).
%% @end
%%--------------------------------------------------------------------
-spec await_projections() -> pid().
await_projections() ->
    spawn(fun() ->
        Deadline = erlang:monotonic_time(millisecond) + ?TIMEOUT_MS,
        wait_loop(Deadline),
        hecate_lifecycle:set_state(running),
        logger:info("[readiness] Projections caught up — daemon ready")
    end).

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

wait_loop(Deadline) ->
    case erlang:monotonic_time(millisecond) > Deadline of
        true ->
            logger:warning("[readiness] Timeout after ~bms — setting running anyway",
                           [?TIMEOUT_MS]);
        false ->
            case all_projections_ready() of
                true ->
                    ok;
                false ->
                    timer:sleep(?POLL_INTERVAL_MS),
                    wait_loop(Deadline)
            end
    end.

all_projections_ready() ->
    lists:all(fun store_ready/1, ?STORE_PROJECTIONS).

store_ready({StoreId, EtsTable}) ->
    case ets:info(EtsTable) of
        undefined ->
            %% Table not created — domain app hasn't booted yet.
            %% Don't block on it; the app may not exist.
            true;
        _ ->
            case ets:info(EtsTable, size) of
                0 -> not store_has_events(StoreId);
                _ -> true
            end
    end.

%% @doc Check if a reckon_db store contains at least one event.
%% Returns `true` if store has events, `false` if empty.
%% If the store API is unavailable (Ra not ready), returns `true`
%% to prevent premature readiness (keep waiting).
store_has_events(StoreId) ->
    try esdb_gater_api:stream_forward(StoreId, <<"$all">>, 0, 1) of
        {ok, [_ | _]} -> true;
        {ok, []}       -> false;
        {error, _}     -> true  %% Assume events exist if store is unavailable
    catch
        _:_ -> true  %% Store not ready — assume it has events (keep waiting)
    end.
