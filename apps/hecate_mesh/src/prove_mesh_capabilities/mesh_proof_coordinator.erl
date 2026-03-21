%%% @doc Mesh proof coordinator.
%%%
%%% Orchestrates the mesh proof-of-participation ceremony. Runs 4
%%% probes (pubsub, rpc, dht, content) in parallel, collects results,
%%% announces presence, and transitions the daemon to running.
%%%
%%% Lifecycle:
%%%   1. Starts with proof_status = pending
%%%   2. run_probes/0 called by hecate_readiness -> waiting_mesh
%%%   3. Polls hecate_mesh:is_connected() every 500ms (up to 10s)
%%%   4. Connected: spawns 4 probes as monitored processes -> probing
%%%   5. Collects results via messages + DOWN monitors
%%%   6. Per-probe 5s timeout (kills probe if exceeded)
%%%   7. After all probes: presence announcement -> completed
%%%   8. Transitions daemon to running
%%%   9. Starts 60s heartbeat timer
%%%  10. Mesh never connects (10s): skip probes -> still running (non-fatal)
%%% @end
-module(mesh_proof_coordinator).
-behaviour(gen_server).

-export([start_link/0, run_probes/0, rerun_probes/0, get_proof_results/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2]).

-define(SERVER, ?MODULE).
-define(MESH_WAIT_INTERVAL_MS, 500).
-define(MESH_WAIT_TIMEOUT_MS, 10_000).
-define(PROBE_TIMEOUT_MS, 5_000).
-define(HEARTBEAT_INTERVAL_MS, 60_000).

-define(PROBES, [
    {pubsub, probe_mesh_pubsub},
    {rpc,    probe_mesh_rpc},
    {dht,    probe_mesh_dht},
    {content, probe_mesh_content}
]).

-record(state, {
    proof_status :: pending | waiting_mesh | probing | completed | skipped,
    probes :: #{atom() => map()},
    pending_probes :: #{reference() => {atom(), pid(), reference()}},
    start_time :: integer() | undefined,
    heartbeat_ref :: reference() | undefined,
    presence :: #{atom() => term()},
    is_initial_run :: boolean()
}).

%% -- API -------------------------------------------------------------

start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

-spec run_probes() -> ok.
run_probes() ->
    gen_server:cast(?SERVER, {run_probes, true}).

-spec rerun_probes() -> ok.
rerun_probes() ->
    gen_server:cast(?SERVER, {run_probes, false}).

-spec get_proof_results() -> map().
get_proof_results() ->
    gen_server:call(?SERVER, get_proof_results).

%% -- gen_server callbacks -------------------------------------------

init([]) ->
    {ok, #state{
        proof_status = pending,
        probes = #{},
        pending_probes = #{},
        start_time = undefined,
        heartbeat_ref = undefined,
        presence = #{},
        is_initial_run = false
    }}.

handle_call(get_proof_results, _From, State) ->
    #state{proof_status = Status, probes = Probes,
           start_time = StartTime, presence = Presence} = State,
    Elapsed = case StartTime of
        undefined -> 0;
        T -> erlang:monotonic_time(millisecond) - T
    end,
    Result = #{
        ok => true,
        proof_status => Status,
        elapsed_ms => Elapsed,
        probes => Probes,
        presence => Presence
    },
    {reply, Result, State};

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast({run_probes, IsInitial}, #state{proof_status = probing} = State) ->
    logger:info("[mesh_proof] Probes already in progress, ignoring"),
    {noreply, State#state{is_initial_run = IsInitial orelse State#state.is_initial_run}};
handle_cast({run_probes, IsInitial}, State) ->
    Now = erlang:monotonic_time(millisecond),
    logger:info("[mesh_proof] Starting mesh proof ceremony"),
    broadcast_pg(mesh_proof_started, #{timestamp => erlang:system_time(millisecond)}),
    NewState = State#state{
        proof_status = waiting_mesh,
        probes = #{},
        pending_probes = #{},
        start_time = Now,
        is_initial_run = IsInitial
    },
    case IsInitial of
        true -> hecate_boot_tracker:set_phase(probing_mesh);
        false -> ok
    end,
    self() ! {check_mesh, 0},
    {noreply, NewState};

handle_cast(_Msg, State) ->
    {noreply, State}.

%% -- Mesh connection polling -----------------------------------------

handle_info({check_mesh, Elapsed}, #state{proof_status = waiting_mesh} = State) when Elapsed >= ?MESH_WAIT_TIMEOUT_MS ->
    logger:warning("[mesh_proof] Mesh not connected after ~bms — skipping probes", [Elapsed]),
    skip_probes(State);

handle_info({check_mesh, Elapsed}, #state{proof_status = waiting_mesh} = State) ->
    case hecate_mesh:is_connected() of
        true ->
            logger:info("[mesh_proof] Mesh connected — launching probes"),
            launch_probes(State);
        false ->
            erlang:send_after(?MESH_WAIT_INTERVAL_MS, self(), {check_mesh, Elapsed + ?MESH_WAIT_INTERVAL_MS}),
            {noreply, State}
    end;

%% -- Probe result collection -----------------------------------------

handle_info({probe_result, Name, Result}, #state{pending_probes = Pending, probes = Probes} = State) ->
    case find_probe_by_name(Name, Pending) of
        {ok, MonRef, TimerRef} ->
            erlang:cancel_timer(TimerRef),
            erlang:demonitor(MonRef, [flush]),
            ProbeResult = format_probe_result(Name, Result, State#state.start_time),
            broadcast_probe_progress(Name, ProbeResult),
            NewPending = remove_probe_by_name(Name, Pending),
            NewProbes = Probes#{Name => ProbeResult},
            NewState = State#state{pending_probes = NewPending, probes = NewProbes},
            maybe_complete(NewState);
        not_found ->
            {noreply, State}
    end;

handle_info({probe_timeout, Name}, #state{pending_probes = Pending, probes = Probes} = State) ->
    case find_probe_by_name(Name, Pending) of
        {ok, MonRef, _TimerRef} ->
            {_, Pid, _} = find_probe_entry(Name, Pending),
            exit(Pid, kill),
            erlang:demonitor(MonRef, [flush]),
            ProbeResult = #{status => failed, duration_ms => ?PROBE_TIMEOUT_MS,
                           detail => #{error => timeout}},
            logger:warning("[mesh_proof] Probe ~p timed out after ~bms", [Name, ?PROBE_TIMEOUT_MS]),
            broadcast_probe_progress(Name, ProbeResult),
            NewPending = remove_probe_by_name(Name, Pending),
            NewProbes = Probes#{Name => ProbeResult},
            NewState = State#state{pending_probes = NewPending, probes = NewProbes},
            maybe_complete(NewState);
        not_found ->
            {noreply, State}
    end;

handle_info({'DOWN', MonRef, process, _Pid, Reason}, #state{pending_probes = Pending, probes = Probes} = State) ->
    case maps:find(MonRef, Pending) of
        {ok, {Name, _Pid2, TimerRef}} ->
            erlang:cancel_timer(TimerRef),
            ProbeResult = #{status => failed, duration_ms => 0,
                           detail => #{error => iolist_to_binary(io_lib:format("~p", [Reason]))}},
            logger:warning("[mesh_proof] Probe ~p crashed: ~p", [Name, Reason]),
            broadcast_probe_progress(Name, ProbeResult),
            NewPending = maps:remove(MonRef, Pending),
            NewProbes = Probes#{Name => ProbeResult},
            NewState = State#state{pending_probes = NewPending, probes = NewProbes},
            maybe_complete(NewState);
        error ->
            {noreply, State}
    end;

%% -- Heartbeat -------------------------------------------------------

handle_info(heartbeat, #state{proof_status = completed, probes = Probes} = State) ->
    spawn(fun() ->
        case hecate_mesh:get_client() of
            {ok, Client} when is_pid(Client) ->
                announce_mesh_presence:announce(Client, Probes);
            _ ->
                ok
        end
    end),
    Ref = erlang:send_after(?HEARTBEAT_INTERVAL_MS, self(), heartbeat),
    {noreply, State#state{heartbeat_ref = Ref}};

handle_info(heartbeat, State) ->
    Ref = erlang:send_after(?HEARTBEAT_INTERVAL_MS, self(), heartbeat),
    {noreply, State#state{heartbeat_ref = Ref}};

handle_info(_Msg, State) ->
    {noreply, State}.

%% -- Internal --------------------------------------------------------

launch_probes(State) ->
    {ok, Client} = hecate_mesh:get_client(),
    Self = self(),
    PendingMap = lists:foldl(fun({Name, Mod}, Acc) ->
        Pid = spawn(fun() ->
            Result = try Mod:run(Client)
                     catch Class:Reason:Stack ->
                         logger:warning("[mesh_proof] Probe ~p exception: ~p:~p~n~p",
                                        [Name, Class, Reason, Stack]),
                         {error, {exception, Class, Reason}}
                     end,
            Self ! {probe_result, Name, Result}
        end),
        MonRef = erlang:monitor(process, Pid),
        TimerRef = erlang:send_after(?PROBE_TIMEOUT_MS, Self, {probe_timeout, Name}),
        Acc#{MonRef => {Name, Pid, TimerRef}}
    end, #{}, ?PROBES),
    {noreply, State#state{proof_status = probing, pending_probes = PendingMap}}.

skip_probes(State) ->
    Probes = maps:from_list([{Name, #{status => skipped, duration_ms => 0,
                                       detail => #{reason => mesh_not_connected}}}
                              || {Name, _Mod} <- ?PROBES]),
    broadcast_pg(mesh_proof_completed, #{
        proof_status => skipped,
        probes => Probes,
        elapsed_ms => erlang:monotonic_time(millisecond) - State#state.start_time
    }),
    transition_to_running(State#state{proof_status = skipped, probes = Probes}).

maybe_complete(#state{pending_probes = Pending} = State) when map_size(Pending) =:= 0 ->
    complete_probes(State);
maybe_complete(State) ->
    {noreply, State}.

complete_probes(#state{probes = Probes, start_time = StartTime} = State) ->
    Elapsed = erlang:monotonic_time(millisecond) - StartTime,
    Passed = maps:size(maps:filter(fun(_, #{status := S}) -> S =:= passed end, Probes)),
    Total = maps:size(Probes),
    logger:info("[mesh_proof] Proof complete: ~b/~b passed in ~bms", [Passed, Total, Elapsed]),

    broadcast_pg(mesh_proof_completed, #{
        proof_status => completed,
        probes => Probes,
        elapsed_ms => Elapsed
    }),

    %% Announce presence
    spawn(fun() ->
        case hecate_mesh:get_client() of
            {ok, Client} when is_pid(Client) ->
                case announce_mesh_presence:announce(Client, Probes) of
                    ok -> logger:info("[mesh_proof] Presence announced");
                    {error, Reason} -> logger:warning("[mesh_proof] Presence announce failed: ~p", [Reason])
                end;
            _ ->
                logger:warning("[mesh_proof] Cannot announce presence — no mesh client")
        end
    end),

    NewState = State#state{
        proof_status = completed,
        presence = #{
            last_announced => erlang:system_time(millisecond),
            heartbeat_interval_ms => ?HEARTBEAT_INTERVAL_MS
        }
    },
    transition_to_running(NewState).

transition_to_running(#state{is_initial_run = true} = State) ->
    hecate_lifecycle:set_state(running),
    hecate_boot_tracker:set_running(),
    logger:info("[mesh_proof] Daemon ready — transitioning to running"),
    Ref = erlang:send_after(?HEARTBEAT_INTERVAL_MS, self(), heartbeat),
    {noreply, State#state{heartbeat_ref = Ref}};
transition_to_running(State) ->
    %% Re-run: don't touch lifecycle, just restart heartbeat
    case State#state.heartbeat_ref of
        undefined -> ok;
        OldRef -> erlang:cancel_timer(OldRef)
    end,
    Ref = erlang:send_after(?HEARTBEAT_INTERVAL_MS, self(), heartbeat),
    {noreply, State#state{heartbeat_ref = Ref}}.

format_probe_result(Name, {ok, Detail}, StartTime) ->
    Duration = erlang:monotonic_time(millisecond) - StartTime,
    logger:info("[mesh_proof] Probe ~p: passed (~bms)", [Name, Duration]),
    #{status => passed, duration_ms => Duration, detail => Detail};
format_probe_result(Name, {error, Reason}, StartTime) ->
    Duration = erlang:monotonic_time(millisecond) - StartTime,
    ErrorBin = iolist_to_binary(io_lib:format("~p", [Reason])),
    logger:warning("[mesh_proof] Probe ~p: failed (~bms) — ~s", [Name, Duration, ErrorBin]),
    #{status => failed, duration_ms => Duration, detail => #{error => ErrorBin}}.

find_probe_by_name(Name, Pending) ->
    case [MonRef || {MonRef, {N, _, _}} <- maps:to_list(Pending), N =:= Name] of
        [MonRef] ->
            {_, _, TimerRef} = maps:get(MonRef, Pending),
            {ok, MonRef, TimerRef};
        [] ->
            not_found
    end.

find_probe_entry(Name, Pending) ->
    [Entry] = [E || {_, {N, _, _} = E} <- maps:to_list(Pending), N =:= Name],
    Entry.

remove_probe_by_name(Name, Pending) ->
    maps:filter(fun(_MonRef, {N, _, _}) -> N =/= Name end, Pending).

broadcast_pg(EventType, Data) ->
    Members = try pg:get_members(pg, macula_mesh_lifecycle) catch _:_ -> [] end,
    Msg = {macula_mesh_event, EventType, Data},
    [Pid ! Msg || Pid <- Members],
    ok.

broadcast_probe_progress(Name, ProbeResult) ->
    broadcast_pg(mesh_proof_progress, #{
        probe => Name,
        status => maps:get(status, ProbeResult),
        duration_ms => maps:get(duration_ms, ProbeResult)
    }).
