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

%% Stores and their PRIMARY ETS projection tables.
%% Only list tables that MUST have data if their store has any events.
%% Do NOT list tables that depend on specific event types which may
%% not exist yet (e.g., `licenses` depends on license_bought_v1 which
%% only exists after a purchase — not after initial catalog seeding).
-define(STORE_PROJECTIONS, [
    {settings_store,          settings},
    {realm_memberships_store, realm_memberships},
    {license_offerings_store, offerings},
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
        hecate_boot_tracker:set_running(),
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
                0 ->
                    HasEvents = store_has_events(StoreId),
                    case HasEvents of
                        true ->
                            logger:info("[readiness] Waiting: ~p ETS ~p empty but store has events",
                                        [StoreId, EtsTable]);
                        false ->
                            ok
                    end,
                    not HasEvents;
                _ -> true
            end
    end.

store_has_events(StoreId) ->
    try evoq_event_store:has_events(StoreId)
    catch
        _:_ -> true  %% Store not ready — assume it has events (keep waiting)
    end.
