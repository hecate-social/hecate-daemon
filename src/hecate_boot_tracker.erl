%%%-------------------------------------------------------------------
%%% @doc Boot tracker — polls reckon_db_sup for store readiness.
%%%
%%% Polls reckon_db_sup:which_stores/0 every 500ms to track which
%%% stores are ready. When all expected stores appear (or 60s timeout),
%%% triggers post-boot: subscriptions -> routes -> readiness.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_boot_tracker).
-behaviour(gen_server).

-export([start_link/1, get_status/0, set_running/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(BOOT_TIMEOUT_MS, 60_000).
-define(POLL_INTERVAL_MS, 500).

-record(state, {
    expected_stores :: [atom()],
    ready_stores :: #{atom() => integer()},
    boot_phase :: booting_stores | starting_subscriptions | replaying | running,
    start_time :: integer(),
    post_boot_triggered :: boolean()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link([atom()]) -> {ok, pid()} | {error, term()}.
start_link(StoreIds) ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, StoreIds, []).

-spec get_status() -> map().
get_status() ->
    gen_server:call(?SERVER, get_status).

-spec set_running() -> ok.
set_running() ->
    gen_server:cast(?SERVER, set_running).

%%====================================================================
%% gen_server callbacks
%%====================================================================

init(StoreIds) ->
    Now = erlang:monotonic_time(millisecond),
    logger:info("[hecate_boot_tracker:init/1] tracking ~b stores: ~p",
                [length(StoreIds), StoreIds]),

    erlang:send_after(?POLL_INTERVAL_MS, self(), poll_stores),
    erlang:send_after(?BOOT_TIMEOUT_MS, self(), boot_timeout),

    {ok, #state{
        expected_stores = StoreIds,
        ready_stores = #{},
        boot_phase = booting_stores,
        start_time = Now,
        post_boot_triggered = false
    }}.

handle_call(get_status, _From, State) ->
    #state{
        expected_stores = Expected,
        ready_stores = Ready,
        boot_phase = Phase,
        start_time = StartTime
    } = State,
    Elapsed = erlang:monotonic_time(millisecond) - StartTime,
    StoreStatuses = maps:from_list([
        {atom_to_binary(S), case maps:is_key(S, Ready) of
            true -> <<"ready">>;
            false -> <<"starting">>
        end}
     || S <- Expected]),
    Status = #{
        boot_phase => atom_to_binary(Phase),
        stores => StoreStatuses,
        stores_ready => map_size(Ready),
        stores_total => length(Expected),
        elapsed_ms => Elapsed
    },
    {reply, Status, State};

handle_call(Msg, _From, State) ->
    logger:warning("[hecate_boot_tracker:handle_call/3] unexpected: ~p", [Msg]),
    {reply, {error, unknown}, State}.

handle_cast({set_phase, Phase}, State) ->
    logger:info("[hecate_boot_tracker:handle_cast/2] phase -> ~p", [Phase]),
    {noreply, State#state{boot_phase = Phase}};

handle_cast(set_running, State) ->
    logger:info("[hecate_boot_tracker:handle_cast/2] phase -> running (boot complete)"),
    {noreply, State#state{boot_phase = running}};

handle_cast(Msg, State) ->
    logger:warning("[hecate_boot_tracker:handle_cast/2] unexpected: ~p", [Msg]),
    {noreply, State}.

handle_info(poll_stores, #state{boot_phase = booting_stores} = State) ->
    #state{expected_stores = Expected, ready_stores = Ready} = State,
    Running = try reckon_db_sup:which_stores() catch _:_ -> [] end,
    NewlyReady = [S || S <- Running,
                       lists:member(S, Expected),
                       not maps:is_key(S, Ready)],
    Now = erlang:monotonic_time(millisecond),
    NewReady = lists:foldl(fun(S, Acc) -> Acc#{S => Now} end, Ready, NewlyReady),

    %% Log each newly discovered store
    lists:foreach(fun(S) ->
        logger:info("[hecate_boot_tracker:poll_stores] ~p ready (~b/~b)",
                    [S, map_size(NewReady), length(Expected)])
    end, NewlyReady),

    NewState = State#state{ready_stores = NewReady},
    case map_size(NewReady) =:= length(Expected) of
        true ->
            trigger_post_boot(NewState);
        false ->
            erlang:send_after(?POLL_INTERVAL_MS, self(), poll_stores),
            {noreply, NewState}
    end;

handle_info(poll_stores, State) ->
    {noreply, State};

handle_info(boot_timeout, #state{boot_phase = booting_stores} = State) ->
    #state{expected_stores = Expected, ready_stores = Ready} = State,
    Missing = [S || S <- Expected, not maps:is_key(S, Ready)],
    logger:warning("[hecate_boot_tracker:boot_timeout] ~bms elapsed, missing: ~p",
                   [?BOOT_TIMEOUT_MS, Missing]),
    logger:warning("[hecate_boot_tracker:boot_timeout] partial boot (~b/~b stores)",
                   [map_size(Ready), length(Expected)]),
    trigger_post_boot(State);

handle_info(boot_timeout, State) ->
    {noreply, State};

handle_info(Msg, State) ->
    logger:warning("[hecate_boot_tracker:handle_info/2] unexpected: ~p", [Msg]),
    {noreply, State}.

%%====================================================================
%% Internal
%%====================================================================

trigger_post_boot(#state{post_boot_triggered = true} = State) ->
    {noreply, State};
trigger_post_boot(#state{ready_stores = Ready, start_time = StartTime} = State) ->
    Elapsed = erlang:monotonic_time(millisecond) - StartTime,
    ReadyStoreIds = maps:keys(Ready),
    logger:info("[hecate_boot_tracker:trigger_post_boot/1] ~b stores in ~bms",
                [map_size(Ready), Elapsed]),

    NewState = State#state{
        boot_phase = starting_subscriptions,
        post_boot_triggered = true
    },

    spawn(fun() -> run_post_boot(ReadyStoreIds) end),
    {noreply, NewState}.

run_post_boot(ReadyStoreIds) ->
    logger:info("[hecate_boot_tracker:run_post_boot/1] starting subscriptions for ~b stores",
                [length(ReadyStoreIds)]),
    hecate_app:start_store_subscriptions(ReadyStoreIds),

    logger:info("[hecate_boot_tracker:run_post_boot/1] compiling routes"),
    Dispatch = hecate_api_routes:compile(),
    cowboy:set_env(hecate_socket_listener, dispatch, Dispatch),
    logger:info("[hecate_boot_tracker:run_post_boot/1] routes hot-swapped"),

    gen_server:cast(?SERVER, {set_phase, replaying}),

    logger:info("[hecate_boot_tracker:run_post_boot/1] awaiting projection replay"),
    hecate_readiness:await_projections().
