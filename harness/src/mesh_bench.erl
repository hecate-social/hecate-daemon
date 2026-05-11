%%% @doc mesh-bench — quantitative latency/throughput probes against the live
%%% mesh, with percentiles + a histogram. The `bench_mesh' engine in
%%% harness-script form (no daemon needed — transient `macula:connect' pool);
%%% lift this into `apps/hecate_mesh/src/run_mesh_bench/' + a
%%% `GET /api/mesh/bench' route + a hecate-web `/mesh/bench' chart when the
%%% daemon-side wiring goes in.
%%%
%%% v1 probes (each fires N round-trips, reports min/p50/p90/p99/max/mean +
%%% ok/fail + a log-bucket histogram):
%%%   - dht_find  : put one signed station_endpoint once, then `find_record' it
%%%                 back N times — steady-state DHT read latency
%%%   - dht_put   : re-put that record N times — DHT write latency
%%%   - pubsub    : subscribe to a private `_bench.*' topic, publish a seq'd
%%%                 payload N times, time publish→deliver (needs the station to
%%%                 echo self-publishes; if it doesn't, all timeouts → reported)
%%%
%%% RPC, content-block (`put_content'/`get_content'), and stream-throughput
%%% (`call_stream') probes are follow-ups (the unary-RPC pool API in macula 4.3
%%% needs nailing down — the daemon's existing `probe_mesh_rpc' calls a removed
%%% `macula:advertise/3`/`call/3`).
%%%
%%% Bare `erl': no distribution, no -heart, no disk writes. The records it puts
%%% are transient RFC 3849 doc-prefix test artefacts (~5-min TTL).
%%% @end
-module(mesh_bench).
-export([main/0, run/2, render/2]).

%%====================================================================
%% main/0 — entry point for harness/mesh-bench.sh
%%====================================================================

main() ->
    M = harness_mesh,
    M:say("~ts", [M:bold("mesh-bench  —  quantitative mesh latency probes")]),
    N = int_env("HARNESS_BENCH_N", 30),
    Probes = probes_env("HARNESS_BENCH_PROBES", [dht_find, dht_put, pubsub]),
    case M:connect(#{connect_budget_ms => 40000}) of
        {ok, Pool} ->
            M:say("~ts", [M:dim(io_lib:format("~b iterations × ~b probe(s): ~p — this takes a minute …",
                                              [N, length(Probes), Probes]))]),
            render(M, run(Pool, #{iterations => N, probes => Probes})),
            halt(0);
        {error, Why} ->
            M:say("~ts ~p", [M:red("× could not reach the mesh:"), Why]), halt(1)
    end.

int_env(Name, Def) ->
    case os:getenv(Name) of
        V when V =:= false; V =:= "" -> Def;
        S -> case string:to_integer(string:trim(S)) of {I, _} when is_integer(I), I > 0 -> I; _ -> Def end
    end.

probes_env(Name, Def) ->
    case os:getenv(Name) of
        V when V =:= false; V =:= "" -> Def;
        S -> case [list_to_atom(string:trim(P)) || P <- string:split(S, ",", all), string:trim(P) =/= ""] of
                 [] -> Def; L -> L
             end
    end.

-define(TEST_V6,   <<"2001:db8:dead:beef::1">>).
-define(TEST_PORT, 4433).
-define(STORAGE_DOMAIN_STATION_ENDPOINT, <<"station_endpoint">>).
-define(PUBSUB_TIMEOUT_MS, 4000).

%%====================================================================
%% run/2 — fire the probes, return results
%%====================================================================

%% Opts: iterations (default 30), probes (default [dht_find, dht_put, pubsub]).
-spec run(pid(), map()) -> #{iterations := pos_integer(), results := [map()],
                              started_at := integer(), finished_at := integer()}.
run(Pool, Opts) ->
    N = maps:get(iterations, Opts, 30),
    Which = maps:get(probes, Opts, [dht_find, dht_put, pubsub]),
    T0 = erlang:system_time(millisecond),
    Results = [probe(P, Pool, N) || P <- Which],
    #{iterations => N, results => Results,
      started_at => T0, finished_at => erlang:system_time(millisecond)}.

probe(Which, Pool, N) ->
    {Setup, Round, Teardown} = probe_fns(Which, Pool),
    Ctx0 = Setup(),
    {Samples, Errs} = lists:foldl(
        fun(_I, {Acc, E}) ->
            T = erlang:monotonic_time(microsecond),
            case Round(Ctx0) of
                ok    -> {[(erlang:monotonic_time(microsecond) - T) / 1000.0 | Acc], E};
                {error, R} -> {Acc, [R | E]}
            end
        end, {[], []}, lists:seq(1, N)),
    Teardown(Ctx0),
    Lat = lists:sort(Samples),
    #{probe   => Which,
      n       => N,
      ok      => length(Lat),
      failed  => length(Errs),
      errors  => count_errs(Errs),
      latency_ms => stats(Lat),
      histogram  => histogram(Lat)}.

%%====================================================================
%% the probes
%%====================================================================

probe_fns(dht_find, Pool) ->
    Setup = fun() ->
        {Pub, KP} = fresh_id(),
        Rec = sign_station(Pub, KP),
        Key = crypto:hash(sha256, <<?STORAGE_DOMAIN_STATION_ENDPOINT/binary, Pub/binary>>),
        ok = put_with_retry(Pool, Rec, 6),
        %% wait until it's findable so the first sample isn't a cold miss
        ok = wait_findable(Pool, Key, 12),
        Key
    end,
    Round = fun(Key) -> case macula:find_record(Pool, Key) of {ok, _} -> ok; E -> E end end,
    {Setup, Round, fun(_) -> ok end};

probe_fns(dht_put, Pool) ->
    Setup = fun() -> fresh_id() end,    %% {Pub, KP}
    Round = fun({Pub, KP}) ->
        %% a fresh version each time (new UUIDv7 + expires_at), same key
        case macula:put_record(Pool, sign_station(Pub, KP)) of ok -> ok; E -> E end
    end,
    {Setup, Round, fun(_) -> ok end};

probe_fns(pubsub, Pool) ->
    Setup = fun() ->
        Realm = macula_realm:id(<<"io.macula">>),
        Topic = <<"_bench.pubsub.", (binary:encode_hex(crypto:strong_rand_bytes(8)))/binary>>,
        Self = self(),
        Cb = fun(_T, Payload, _M) -> Self ! {bench_pubsub, Payload} end,
        case macula:subscribe_callback(Pool, Realm, Topic, Cb) of
            {ok, SubRef} -> timer:sleep(150), {ok, Realm, Topic, SubRef};
            {error, R}   -> {error_setup, R}
        end
    end,
    Round = fun({ok, Realm, Topic, _SubRef}) ->
                    Seq = erlang:unique_integer([positive]),
                    case macula:publish(Pool, Realm, Topic, <<Seq:64>>) of
                        ok ->
                            receive
                                {bench_pubsub, <<Seq:64>>} -> ok
                            after ?PUBSUB_TIMEOUT_MS -> drain_pubsub(), {error, deliver_timeout}
                            end;
                        {error, R} -> {error, R}
                    end;
               ({error_setup, R}) -> {error, {subscribe_failed, R}}
            end,
    Teardown = fun({ok, _R, _T, SubRef}) -> catch macula:unsubscribe(Pool, SubRef), ok;
                  (_) -> ok end,
    {Setup, Round, Teardown}.

drain_pubsub() -> receive {bench_pubsub, _} -> drain_pubsub() after 0 -> ok end.

%%====================================================================
%% station_endpoint test record
%%====================================================================

fresh_id() -> #{public := Pub} = KP = macula_identity:generate(), {Pub, KP}.

sign_station(Pub, KP) ->
    macula_record:sign(
      macula_record:station_endpoint(Pub, ?TEST_PORT, #{host_advertised => [?TEST_V6]}), KP).

put_with_retry(_Pool, _Rec, 0) -> {error, exhausted};
put_with_retry(Pool, Rec, N) ->
    case macula:put_record(Pool, Rec) of ok -> ok; {error, _} -> timer:sleep(1500), put_with_retry(Pool, Rec, N - 1) end.

wait_findable(_Pool, _Key, 0) -> {error, never_findable};
wait_findable(Pool, Key, N) ->
    case macula:find_record(Pool, Key) of {ok, _} -> ok; _ -> timer:sleep(800), wait_findable(Pool, Key, N - 1) end.

%%====================================================================
%% stats
%%====================================================================

stats([]) -> #{min => null, p50 => null, p90 => null, p99 => null, max => null, mean => null};
stats(Sorted) ->
    L = length(Sorted),
    Pick = fun(P) -> lists:nth(max(1, min(L, round(P * L))), Sorted) end,
    #{min  => hd(Sorted),
      p50  => Pick(0.50),
      p90  => Pick(0.90),
      p99  => Pick(0.99),
      max  => lists:last(Sorted),
      mean => lists:sum(Sorted) / L}.

%% log-ish buckets (ms): [0,1) [1,2) [2,5) [5,10) [10,20) [20,50) [50,100) [100,200) [200,500) [500,∞)
-define(BUCKETS, [1, 2, 5, 10, 20, 50, 100, 200, 500]).
histogram(Samples) ->
    NB = length(?BUCKETS) + 1,
    Counts = lists:foldl(
        fun(V, Cs) ->
            I = bucket_idx(V, ?BUCKETS, 0),
            setnth(I + 1, Cs, lists:nth(I + 1, Cs) + 1)
        end, lists:duplicate(NB, 0), Samples),
    [{label_for(I - 1), lists:nth(I, Counts)} || I <- lists:seq(1, NB)].

bucket_idx(_V, [], I) -> I;
bucket_idx(V, [E | _], I) when V < E -> I;
bucket_idx(V, [_ | Rest], I) -> bucket_idx(V, Rest, I + 1).

setnth(1, [_ | T], V) -> [V | T];
setnth(N, [H | T], V) -> [H | setnth(N - 1, T, V)].

label_for(0) -> "<1ms";
label_for(N) when N >= 1, N =< length(?BUCKETS) - 1 ->
    io_lib:format("~w-~wms", [lists:nth(N, ?BUCKETS), lists:nth(N + 1, ?BUCKETS)]);
label_for(_) -> "≥500ms".

count_errs(Errs) ->
    lists:foldl(fun(E, M) -> maps:update_with(E, fun(C) -> C + 1 end, 1, M) end, #{}, Errs).

%%====================================================================
%% render/2 — pretty output via harness_mesh
%%====================================================================

render(M, #{iterations := N, results := Rs, started_at := T0, finished_at := T1}) ->
    M:hdr("mesh-bench"),
    M:kv("iterations / probe", integer_to_list(N)),
    M:kv("wall clock", io_lib:format("~.1f s", [(T1 - T0) / 1000.0])),
    M:say(""),
    [render_probe(M, R) || R <- Rs],
    ok.

render_probe(M, #{probe := P, n := N, ok := Ok, failed := F, errors := Errs,
                  latency_ms := S, histogram := H}) ->
    M:say("~ts  ~ts", [M:bold(probe_name(P)),
                       case F of 0 -> M:dim(io_lib:format("~b/~b ok", [Ok, N]));
                                 _ -> M:yellow(io_lib:format("~b/~b ok, ~b failed: ~p", [Ok, N, F, Errs])) end]),
    M:rule(),
    case S of
        #{min := null} -> M:say("  ~ts", [M:red("no successful samples")]);
        #{min := Mn, p50 := P50, p90 := P90, p99 := P99, max := Mx, mean := Me} ->
            M:table(["min", "p50", "p90", "p99", "max", "mean"],
                    [[ms(Mn), ms(P50), ms(P90), ms(P99), ms(Mx), ms(Me)]]),
            M:say(""),
            Total = lists:sum([C || {_, C} <- H]),
            [M:say("  ~-10ts ~ts ~ts", [Lbl, bar(C, Total), M:dim(integer_to_list(C))]) || {Lbl, C} <- H, C > 0]
    end,
    M:say("").

ms(null) -> "—";
ms(V) when is_float(V) -> io_lib:format("~.2f", [V]);
ms(V) -> io_lib:format("~p", [V]).

bar(0, _) -> "";
bar(C, Total) when Total > 0 ->
    W = max(1, round(C / Total * 30)),
    lists:duplicate(W, $█);
bar(_, _) -> "".

probe_name(dht_find) -> "DHT find  (find_record, steady-state)";
probe_name(dht_put)  -> "DHT put   (put_record)";
probe_name(pubsub)   -> "PubSub    (publish → deliver round-trip)";
probe_name(X)        -> atom_to_list(X).
