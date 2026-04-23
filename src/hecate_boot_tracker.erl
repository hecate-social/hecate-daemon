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

-export([start_link/1, get_status/0, set_running/0, set_phase/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(BOOT_TIMEOUT_MS, 120_000).
-define(POLL_INTERVAL_MS, 1_000).

-record(state, {
    expected_stores :: [atom()],
    ready_stores :: #{atom() => integer()},
    boot_phase :: booting_stores | starting_subscriptions | replaying | probing_mesh | running,
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

-spec set_phase(atom()) -> ok.
set_phase(Phase) ->
    gen_server:cast(?SERVER, {set_phase, Phase}).

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
    #state{expected_stores = Expected, ready_stores = Ready, start_time = StartTime} = State,
    %% Don't call reckon_db_sup:which_stores() — it does supervisor:which_children()
    %% which blocks when the supervisor is busy starting stores.
    %% Instead, check if each store's manager process is registered.
    Running = [S || S <- Expected, is_store_registered(S)],
    NewlyReady = [S || S <- Running,
                       lists:member(S, Expected),
                       not maps:is_key(S, Ready)],
    Now = erlang:monotonic_time(millisecond),
    NewReady = lists:foldl(fun(S, Acc) -> Acc#{S => Now} end, Ready, NewlyReady),

    %% Log each newly discovered store
    lists:foreach(fun(S) ->
        Elapsed = Now - StartTime,
        logger:info("[hecate_boot_tracker] ~p ready (~b/~b) after ~bms",
                    [S, map_size(NewReady), length(Expected), Elapsed])
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

%% @private Check if a store's manager process is registered (non-blocking).
%% Uses reckon_db_naming convention: reckon_db_store_mgr_{StoreId}.
-spec is_store_registered(atom()) -> boolean().
is_store_registered(StoreId) ->
    MgrName = reckon_db_naming:store_mgr_name(StoreId),
    is_pid(whereis(MgrName)).

run_post_boot(ReadyStoreIds) ->
    try
        logger:info("[boot] Starting subscriptions for ~b stores", [length(ReadyStoreIds)]),
        hecate_app:start_store_subscriptions(ReadyStoreIds),

        logger:info("[boot] Compiling and swapping routes"),
        Dispatch = hecate_api_routes:compile(),
        cowboy:set_env(hecate_socket_listener, dispatch, Dispatch),
        logger:info("[boot] Routes hot-swapped — API ready"),

        gen_server:cast(?SERVER, {set_phase, replaying}),

        logger:info("[boot] Awaiting projection replay"),
        hecate_readiness:await_projections(),

        %% Cluster joins AFTER local readiness — never block boot on network
        maybe_join_cluster(ReadyStoreIds)
    catch Class:Reason:Stack ->
        logger:error("[boot] Post-boot FAILED: ~p:~p~n~p", [Class, Reason, Stack]),
        %% Still swap routes even if subscriptions/replay failed
        try
            Dispatch2 = hecate_api_routes:compile(),
            cowboy:set_env(hecate_socket_listener, dispatch, Dispatch2),
            logger:warning("[boot] Routes swapped despite post-boot failure")
        catch _:_ -> ok
        end
    end.

%% @private Set up Erlang-level clustering (optional) and Khepri
%% store joins (explicit opt-in).
%%
%% Three layers, each opt-in:
%%   HECATE_ERLANG_COOKIE=<atom>        set the distribution cookie
%%   HECATE_CLUSTER_PEERS=<csv>         connect_node on each peer (pg
%%                                      broadcast works at this level)
%%   HECATE_AUTOJOIN_STORES=true        spawn Khepri store joins against
%%                                      the first connected peer (DANGER:
%%                                      replaces local store data with a
%%                                      snapshot from the target's
%%                                      leader — only safe when all
%%                                      stores across the cluster are
%%                                      known to share the same state
%%                                      or local state is expendable)
maybe_join_cluster(StoreIds) ->
    Cookie   = os:getenv("HECATE_ERLANG_COOKIE"),
    Peers    = os:getenv("HECATE_CLUSTER_PEERS"),
    AutoJoin = os:getenv("HECATE_AUTOJOIN_STORES") =:= "true",
    _ = maybe_apply_cookie(Cookie),
    ConnectedPeers = maybe_connect_peers(Peers),
    maybe_spawn_store_joins(AutoJoin, ConnectedPeers, StoreIds).

maybe_apply_cookie(false) ->
    logger:info("[boot] No cluster cookie — keeping vm.args default"),
    skipped;
maybe_apply_cookie(Cookie) when is_list(Cookie) ->
    erlang:set_cookie(node(), list_to_atom(Cookie)),
    logger:info("[boot] Cluster cookie applied from HECATE_ERLANG_COOKIE"),
    applied.

maybe_connect_peers(false) ->
    logger:info("[boot] No cluster peers — staying Erlang-unconnected"),
    [];
maybe_connect_peers(Peers) when is_list(Peers) ->
    PeerNodes = [list_to_atom(string:trim(N)) || N <- string:split(Peers, ",", all), N =/= ""],
    Connected = [P || P <- PeerNodes, net_kernel:connect_node(P) =:= true],
    logger:info("[boot] Erlang cluster: ~b/~b peers connected (~p)",
                [length(Connected), length(PeerNodes), Connected]),
    Connected.

maybe_spawn_store_joins(false, _Connected, _StoreIds) ->
    logger:info("[boot] HECATE_AUTOJOIN_STORES not 'true' — Khepri stores stay local "
                "(pg-based cluster-inherited mesh creds still work at the Erlang layer)");
maybe_spawn_store_joins(true, [], _StoreIds) ->
    logger:info("[boot] HECATE_AUTOJOIN_STORES=true but no peers connected — nothing to join");
maybe_spawn_store_joins(true, _Connected, StoreIds) ->
    logger:info("[boot] Initiating Khepri cluster joins for ~b stores", [length(StoreIds)]),
    lists:foreach(fun(StoreId) ->
        spawn(fun() ->
            case reckon_db_store_coordinator:join_cluster(StoreId) of
                ok          -> logger:info("[boot] Cluster join ok: ~p", [StoreId]);
                coordinator -> logger:info("[boot] Coordinator: ~p", [StoreId]);
                {error, Reason} ->
                    logger:warning("[boot] Cluster join failed ~p: ~p", [StoreId, Reason])
            end
        end)
    end, StoreIds).
