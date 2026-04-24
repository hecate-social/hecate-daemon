%%% @doc Boot tracker — spawns stores, polls readiness, sequences post-boot.
%%%
%%% Lifecycle:
%%%   1. init/1     — starts in waiting_registration phase, no store list yet.
%%%   2. register_stores/1 — hecate_app hands over the store catalog;
%%%                   boot_tracker spawns each store sequentially, transitions
%%%                   to booting_stores, and begins polling manager
%%%                   registrations.
%%%   3. poll_stores — every 1s, check which store-manager procs are up.
%%%      When all expected stores are registered (or boot_timeout fires),
%%%      trigger post-boot.
%%%   4. post-boot (spawned, off the gen_server):
%%%         * start per-store subscriptions
%%%         * compile + hot-swap API routes
%%%         * await projection replay
%%%         * connect Erlang peers (HECATE_CLUSTER_PEERS)
%%%         * optional Khepri cluster joins (HECATE_AUTOJOIN_STORES)
%%%
%%% Moved from hecate_boot_tracker in the boot_daemon carve-out. The
%%% previous module stayed inside hecate_sup which contained business
%%% workers too; splitting into its own app makes the tier-0 / tier-1
%%% boundary explicit and lets business workers rely on boot completion
%%% without a racy gen_server tree.
%%% @end
-module(boot_tracker).
-behaviour(gen_server).

-include_lib("reckon_db/include/reckon_db.hrl").

-export([start_link/0, register_stores/1,
         get_status/0, set_running/0, set_phase/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(BOOT_TIMEOUT_MS, 120_000).
-define(POLL_INTERVAL_MS, 1_000).
-define(STORE_SPAWN_GAP_MS, 500).

-record(state, {
    expected_stores      :: [atom()],
    store_catalog        :: [{atom(), string(), string()}],
    ready_stores         :: #{atom() => integer()},
    boot_phase           :: waiting_registration
                          | booting_stores
                          | starting_subscriptions
                          | replaying
                          | probing_mesh
                          | running,
    start_time           :: integer() | undefined,
    post_boot_triggered  :: boolean()
}).

%%====================================================================
%% API
%%====================================================================

-spec start_link() -> {ok, pid()} | {error, term()}.
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec register_stores([{atom(), string(), string()}]) -> ok.
register_stores(Stores) ->
    gen_server:cast(?SERVER, {register_stores, Stores}).

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

init([]) ->
    logger:info("[boot_tracker] Starting, awaiting store registration"),
    {ok, #state{
        expected_stores     = [],
        store_catalog       = [],
        ready_stores        = #{},
        boot_phase          = waiting_registration,
        start_time          = undefined,
        post_boot_triggered = false
    }}.

handle_call(get_status, _From, State) ->
    #state{expected_stores = Expected, ready_stores = Ready,
           boot_phase = Phase, start_time = StartTime} = State,
    Elapsed = case StartTime of
        undefined -> 0;
        T -> erlang:monotonic_time(millisecond) - T
    end,
    StoreStatuses = maps:from_list([
        {atom_to_binary(S), case maps:is_key(S, Ready) of
            true -> <<"ready">>;
            false -> <<"starting">>
        end}
     || S <- Expected]),
    Status = #{
        boot_phase   => atom_to_binary(Phase),
        stores       => StoreStatuses,
        stores_ready => map_size(Ready),
        stores_total => length(Expected),
        elapsed_ms   => Elapsed
    },
    {reply, Status, State};

handle_call(Msg, _From, State) ->
    logger:warning("[boot_tracker] unexpected call: ~p", [Msg]),
    {reply, {error, unknown}, State}.

handle_cast({register_stores, Stores}, #state{boot_phase = waiting_registration} = State) ->
    Now = erlang:monotonic_time(millisecond),
    StoreIds = [Id || {Id, _, _} <- Stores],
    logger:info("[boot_tracker] registered ~b stores, entering booting_stores",
                [length(StoreIds)]),

    %% Kick off the sequential store spawner off-gen_server; it'll fire-and-forget
    %% each reckon_db_sup:start_store/1 call with a 500ms gap so Ra doesn't
    %% thrash the disk.
    spawn(fun() -> spawn_stores_sequential(Stores) end),

    erlang:send_after(?POLL_INTERVAL_MS, self(), poll_stores),
    erlang:send_after(?BOOT_TIMEOUT_MS, self(), boot_timeout),

    NewState = State#state{
        expected_stores = StoreIds,
        store_catalog   = Stores,
        boot_phase      = booting_stores,
        start_time      = Now
    },
    {noreply, NewState};

handle_cast({register_stores, _}, State) ->
    logger:warning("[boot_tracker] register_stores after registration already handled; ignoring"),
    {noreply, State};

handle_cast({set_phase, Phase}, State) ->
    logger:info("[boot_tracker] phase -> ~p", [Phase]),
    {noreply, State#state{boot_phase = Phase}};

handle_cast(set_running, State) ->
    logger:info("[boot_tracker] phase -> running (boot complete)"),
    {noreply, State#state{boot_phase = running}};

handle_cast(Msg, State) ->
    logger:warning("[boot_tracker] unexpected cast: ~p", [Msg]),
    {noreply, State}.

handle_info(poll_stores, #state{boot_phase = booting_stores} = State) ->
    #state{expected_stores = Expected, ready_stores = Ready, start_time = StartTime} = State,
    %% Don't call reckon_db_sup:which_stores/0 — it does supervisor:which_children/1
    %% which blocks when the supervisor is busy starting stores. Check each
    %% manager's registered name instead (cheap + non-blocking).
    Running = [S || S <- Expected, is_store_registered(S)],
    NewlyReady = [S || S <- Running,
                       lists:member(S, Expected),
                       not maps:is_key(S, Ready)],
    Now = erlang:monotonic_time(millisecond),
    NewReady = lists:foldl(fun(S, Acc) -> Acc#{S => Now} end, Ready, NewlyReady),

    lists:foreach(fun(S) ->
        Elapsed = Now - StartTime,
        logger:info("[boot_tracker] ~p ready (~b/~b) after ~bms",
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
    logger:warning("[boot_tracker] boot_timeout ~bms, missing: ~p", [?BOOT_TIMEOUT_MS, Missing]),
    logger:warning("[boot_tracker] partial boot (~b/~b stores)", [map_size(Ready), length(Expected)]),
    trigger_post_boot(State);

handle_info(boot_timeout, State) ->
    {noreply, State};

handle_info(Msg, State) ->
    logger:warning("[boot_tracker] unexpected info: ~p", [Msg]),
    {noreply, State}.

%%====================================================================
%% Store spawning
%%====================================================================

%% @private Spawn each reckon_db store sequentially with a small gap.
%% Parallel spawns of Ra systems thrash the disk and trip file-lock
%% contention. Runs off-gen_server so a slow store doesn't block us
%% from observing fast ones via poll_stores.
spawn_stores_sequential([]) ->
    logger:info("[boot_tracker] All event stores spawned"),
    ok;
spawn_stores_sequential([{StoreId, SubDir, Label} | Rest]) ->
    Mode = application:get_env(hecate, store_mode, single),
    logger:info("[boot_tracker] Starting ~s event store (~p, mode=~p)...", [Label, StoreId, Mode]),
    DataDir = shared_paths:reckon_path(SubDir),
    ok = filelib:ensure_path(DataDir),
    Config = #store_config{
        store_id         = StoreId,
        data_dir         = DataDir,
        mode             = Mode,
        writer_pool_size = 5,
        reader_pool_size = 5,
        gateway_pool_size = 2,
        options          = #{}
    },
    spawn(fun() ->
        try start_store(Config)
        catch Class:Reason:Stack ->
            logger:error("[boot_tracker] Store ~p crashed: ~p:~p~n~p",
                         [StoreId, Class, Reason, Stack])
        end
    end),
    timer:sleep(?STORE_SPAWN_GAP_MS),
    spawn_stores_sequential(Rest).

start_store(#store_config{store_id = StoreId} = Config) ->
    case reckon_db_sup:start_store(Config) of
        {ok, _Pid} ->
            logger:info("[boot_tracker] Event store ~p ready", [StoreId]);
        {error, {already_started, _Pid}} ->
            logger:info("[boot_tracker] Event store ~p already running", [StoreId]);
        {error, Reason} ->
            logger:error("[boot_tracker] Failed to start event store ~p: ~p", [StoreId, Reason])
    end.

%%====================================================================
%% Post-boot sequencing
%%====================================================================

trigger_post_boot(#state{post_boot_triggered = true} = State) ->
    {noreply, State};
trigger_post_boot(#state{ready_stores = Ready, start_time = StartTime} = State) ->
    Elapsed = erlang:monotonic_time(millisecond) - StartTime,
    ReadyStoreIds = maps:keys(Ready),
    logger:info("[boot_tracker] post_boot: ~b stores ready in ~bms",
                [map_size(Ready), Elapsed]),
    NewState = State#state{
        boot_phase          = starting_subscriptions,
        post_boot_triggered = true
    },
    spawn(fun() -> run_post_boot(ReadyStoreIds) end),
    {noreply, NewState}.

run_post_boot(ReadyStoreIds) ->
    try
        logger:info("[boot_tracker] Starting subscriptions for ~b stores", [length(ReadyStoreIds)]),
        start_store_subscriptions(ReadyStoreIds),

        logger:info("[boot_tracker] Compiling and swapping routes"),
        Dispatch = hecate_api_routes:compile(),
        cowboy:set_env(hecate_socket_listener, dispatch, Dispatch),
        logger:info("[boot_tracker] Routes hot-swapped — API ready"),

        set_phase(replaying),

        logger:info("[boot_tracker] Awaiting projection replay"),
        hecate_readiness:await_projections(),

        %% Cluster joins AFTER local readiness — never block boot on network.
        maybe_join_cluster(ReadyStoreIds)
    catch Class:Reason:Stack ->
        logger:error("[boot_tracker] Post-boot FAILED: ~p:~p~n~p", [Class, Reason, Stack]),
        try
            Dispatch2 = hecate_api_routes:compile(),
            cowboy:set_env(hecate_socket_listener, dispatch, Dispatch2),
            logger:warning("[boot_tracker] Routes swapped despite post-boot failure")
        catch _:_ -> ok
        end
    end.

%% @private Start one evoq_store_subscription per store.
start_store_subscriptions(StoreIds) ->
    lists:foreach(fun(StoreId) ->
        case evoq_store_subscription:start_link(StoreId) of
            {ok, _Pid} ->
                logger:info("[boot_tracker] Store subscription ready for ~p", [StoreId]);
            {error, Reason} ->
                logger:warning("[boot_tracker] Store subscription failed for ~p: ~p",
                               [StoreId, Reason])
        end
    end, StoreIds).

%% @private Connect Erlang peers (HECATE_CLUSTER_PEERS) and optionally
%% do Khepri store joins (HECATE_AUTOJOIN_STORES=true). Cookie is
%% applied in boot_daemon_app:start/2, before any of this.
%%
%%   HECATE_CLUSTER_PEERS=<csv>    connect_node on each peer (pg
%%                                 broadcast works at this level)
%%   HECATE_AUTOJOIN_STORES=true   spawn Khepri store joins against
%%                                 the first connected peer (DANGER:
%%                                 replaces local store data with a
%%                                 snapshot from the target's leader
%%                                 — only safe when all stores across
%%                                 the cluster are known to share the
%%                                 same state or local state is
%%                                 expendable).
maybe_join_cluster(StoreIds) ->
    Peers    = os:getenv("HECATE_CLUSTER_PEERS"),
    AutoJoin = os:getenv("HECATE_AUTOJOIN_STORES") =:= "true",
    ConnectedPeers = maybe_connect_peers(Peers),
    maybe_spawn_store_joins(AutoJoin, ConnectedPeers, StoreIds).

maybe_connect_peers(false) ->
    logger:info("[boot_tracker] No cluster peers — staying Erlang-unconnected"),
    [];
maybe_connect_peers(Peers) when is_list(Peers) ->
    PeerNodes = [list_to_atom(string:trim(N)) || N <- string:split(Peers, ",", all), N =/= ""],
    Connected = [P || P <- PeerNodes, net_kernel:connect_node(P) =:= true],
    logger:info("[boot_tracker] Erlang cluster: ~b/~b peers connected (~p)",
                [length(Connected), length(PeerNodes), Connected]),
    Connected.

maybe_spawn_store_joins(false, _Connected, _StoreIds) ->
    logger:info("[boot_tracker] HECATE_AUTOJOIN_STORES not 'true' — Khepri stores stay local "
                "(pg-based cluster-inherited mesh creds still work at the Erlang layer)");
maybe_spawn_store_joins(true, [], _StoreIds) ->
    logger:info("[boot_tracker] HECATE_AUTOJOIN_STORES=true but no peers connected — nothing to join");
maybe_spawn_store_joins(true, _Connected, StoreIds) ->
    logger:info("[boot_tracker] Initiating Khepri cluster joins for ~b stores", [length(StoreIds)]),
    lists:foreach(fun(StoreId) ->
        spawn(fun() ->
            case reckon_db_store_coordinator:join_cluster(StoreId) of
                ok          -> logger:info("[boot_tracker] Cluster join ok: ~p", [StoreId]);
                coordinator -> logger:info("[boot_tracker] Coordinator: ~p", [StoreId]);
                {error, Reason} ->
                    logger:warning("[boot_tracker] Cluster join failed ~p: ~p", [StoreId, Reason])
            end
        end)
    end, StoreIds).

%%====================================================================
%% Helpers
%%====================================================================

%% @private Check if a store's manager process is registered (non-blocking).
-spec is_store_registered(atom()) -> boolean().
is_store_registered(StoreId) ->
    MgrName = reckon_db_naming:store_mgr_name(StoreId),
    is_pid(whereis(MgrName)).
