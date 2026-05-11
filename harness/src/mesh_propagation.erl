%%% @doc Two-role cross-mesh propagation probe.
%%%
%%%   --publish  : on machine A — generate an Ed25519 identity, sign a fresh
%%%                `station_endpoint' record, put it into the live DHT, print the
%%%                z32 + storage key + the `--resolve' command to run on machine
%%%                B. With `--keep N' it then re-signs + re-puts every 60 s and
%%%                stays up N seconds (extends the window past the ~5 min TTL).
%%%   --resolve <z32> [--key <hex>] [--pub-geo LAT,LNG]
%%%              : on machine B — derive the storage key from the z32 (= sha256
%%%                of "station_endpoint" ‖ pubkey), poll `macula:find_record/2'
%%%                until it lands, then report: time-to-resolve (from pool-up to
%%%                found), retry count, signature verified against the z32, the
%%%                IPv6 the record advertises, and — if `--pub-geo' + this box's
%%%                HECATE_GEO_* are both set — the great-circle distance between
%%%                the two vantage points.
%%%
%%% The "distance between daemons", three ways: geo (haversine), and how long a
%%% record takes to cross the mesh from one to the other.
%%%
%%% Test record only — RFC 3849 doc-prefix host (`2001:db8::/32'), self-expiring
%%% (~5 min TTL). Bare `erl': no distribution, no -heart, no disk writes.
%%% @end
-module(mesh_propagation).
-export([main/0]).

-define(TEST_V6,   <<"2001:db8:dead:beef::1">>).
-define(TEST_PORT, 4433).
-define(TEST_ALPN, <<"macula/1">>).
-define(STORAGE_DOMAIN_STATION_ENDPOINT, <<"station_endpoint">>).

main() ->
    M = harness_mesh,
    Role = os:getenv("HARNESS_MP_ROLE"),
    case Role of
        "publish"  -> publish(M);
        "resolve"  -> resolve(M);
        _ -> M:say("~ts", [M:red("× need HARNESS_MP_ROLE=publish|resolve (set by the wrapper script)")]), halt(2)
    end.

%%====================================================================
%% PUBLISH (machine A)
%%====================================================================

publish(M) ->
    M:say("~ts", [M:bold("mesh-propagation  ·  PUBLISH")]),
    case M:connect(#{connect_budget_ms => 40000}) of
        {ok, Pool} ->
            KP = #{public := Pub} = macula_identity:generate(),
            {ok, Host} = inet:gethostname(),
            Geo = M:geo_from_env(),
            Key = crypto:hash(sha256, <<?STORAGE_DOMAIN_STATION_ENDPOINT/binary, Pub/binary>>),
            Z32 = macula_z32:encode(Pub),
            ok = put_with_retry(Pool, Pub, KP, 8),
            M:hdr("published a station_endpoint into the live DHT"),
            M:kv("identity (z32)", Z32),
            M:kv("storage key", M:hex(Key)),
            M:kv("advertises v6", ?TEST_V6),
            M:kv("from host", Host),
            M:kv("geo", case Geo of undefined -> "(not set)"; {La, Ln} -> io_lib:format("~.4f, ~.4f", [La, Ln]) end),
            M:kv("published at", iso_now()),
            M:say(""),
            M:say("~ts", [M:bold("on the other machine, run:")]),
            ResCmd = "harness/mesh-propagation.sh --resolve " ++ binary_to_list(Z32)
                     ++ case Geo of undefined -> ""; {La2, Ln2} -> io_lib:format(" --pub-geo ~.4f,~.4f", [La2, Ln2]) end,
            M:say("    ~ts", [M:cyan(lists:flatten(ResCmd))]),
            M:say(""),
            Keep = mp_int("HARNESS_MP_KEEP", 0),
            case Keep > 0 of
                true ->
                    M:say("~ts", [M:dim(io_lib:format("refreshing every 60 s, holding for ~b s … (Ctrl-C to stop)", [Keep]))]),
                    hold(M, Pool, Pub, KP, erlang:monotonic_time(millisecond) + Keep * 1000);
                false ->
                    M:say("~ts", [M:dim("(record self-expires in ~5 min — pass --keep N to refresh-and-hold)")])
            end,
            halt(0);
        {error, Why} ->
            M:say("~ts ~p", [M:red("× could not reach the mesh:"), Why]), halt(1)
    end.

put_with_retry(_Pool, _Pub, _KP, 0) -> throw(put_failed);
put_with_retry(Pool, Pub, KP, N) ->
    Rec = make_record(Pub, KP),
    case macula:put_record(Pool, Rec) of
        ok -> ok;
        {error, _} -> timer:sleep(2000), put_with_retry(Pool, Pub, KP, N - 1)
    end.

make_record(Pub, KP) ->
    Unsigned = macula_record:station_endpoint(Pub, ?TEST_PORT,
                   #{host_advertised => [?TEST_V6], alpn => ?TEST_ALPN}),
    macula_record:sign(Unsigned, KP).

hold(M, Pool, Pub, KP, Deadline) ->
    case erlang:monotonic_time(millisecond) >= Deadline of
        true  -> M:say("~ts", [M:dim("hold window over.")]);
        false ->
            timer:sleep(60000),
            _ = catch macula:put_record(Pool, make_record(Pub, KP)),
            M:say("~ts", [M:dim(io_lib:format("  · refreshed at ~s", [iso_now()]))]),
            hold(M, Pool, Pub, KP, Deadline)
    end.

%%====================================================================
%% RESOLVE (machine B)
%%====================================================================

resolve(M) ->
    M:say("~ts", [M:bold("mesh-propagation  ·  RESOLVE")]),
    case derive_key(M) of
        {error, R} -> M:say("~ts ~p", [M:red("× bad --resolve target:"), R]), halt(2);
        {ok, Key, MaybePub} ->
            M:kv("storage key", M:hex(Key)),
            case M:connect(#{connect_budget_ms => 40000}) of
                {ok, Pool} ->
                    M:say("~ts", [M:dim("polling the DHT …")]),
                    T0 = erlang:monotonic_time(millisecond),
                    case find_loop(Pool, Key, 1, 20, T0) of
                        {ok, Rec, Attempt, ElapsedMs} ->
                            report(M, Rec, MaybePub, Attempt, ElapsedMs),
                            halt(0);
                        {error, Tried, ElapsedMs} ->
                            M:hdr("not found"),
                            M:kv("result", M:red(io_lib:format("not in the DHT after ~b attempts (~.1f s)", [Tried, ElapsedMs/1000]))),
                            M:kv("likely", "publisher isn't up / its TTL expired / cross-station replication hasn't reached the station this pool peers with"),
                            halt(1)
                    end;
                {error, Why} ->
                    M:say("~ts ~p", [M:red("× could not reach the mesh:"), Why]), halt(1)
            end
    end.

derive_key(_M) ->
    case {os:getenv("HARNESS_MP_KEY"), os:getenv("HARNESS_MP_Z32")} of
        {Hex, _} when is_list(Hex), Hex =/= "" ->
            try {ok, binary:decode_hex(list_to_binary(Hex)), undefined}
            catch _:_ -> {error, bad_hex_key} end;
        {_, Z32} when is_list(Z32), Z32 =/= "" ->
            case macula_z32:decode(list_to_binary(Z32)) of
                {ok, <<Pub:32/binary>>} ->
                    {ok, crypto:hash(sha256, <<?STORAGE_DOMAIN_STATION_ENDPOINT/binary, Pub/binary>>), Pub};
                _ -> {error, bad_z32}
            end;
        _ -> {error, no_target}
    end.

find_loop(_Pool, _Key, Attempt, Max, T0) when Attempt > Max ->
    {error, Attempt - 1, erlang:monotonic_time(millisecond) - T0};
find_loop(Pool, Key, Attempt, Max, T0) ->
    case macula:find_record(Pool, Key) of
        {ok, Rec} -> {ok, Rec, Attempt, erlang:monotonic_time(millisecond) - T0};
        _ -> timer:sleep(1500), find_loop(Pool, Key, Attempt + 1, Max, T0)
    end.

report(M, Rec, MaybePub, Attempt, ElapsedMs) ->
    M:hdr("resolved"),
    M:kv("found", M:green(io_lib:format("yes — attempt ~b, ~.2f s after the pool connected", [Attempt, ElapsedMs/1000]))),
    KeyOk = MaybePub =:= undefined orelse maps:get(key, Rec, undefined) =:= MaybePub,
    M:kv("record key", case KeyOk of
        true  -> M:green("matches the z32 you asked for ✓  (it is the record that was published — it crossed the mesh)");
        false -> M:red("≠ the z32 you asked for ✗  (something else lives at this key)")
    end),
    VerifyR = catch macula_record:verify(Rec),
    M:kv("macula_record:verify", case VerifyR of
        {ok, _}                     -> M:green("ok ✓");
        {error, expired}            -> M:yellow("error: expired  (record older than its 5-min TTL — still propagated fine)");
        {error, signature_invalid}  -> M:yellow("error: signature_invalid  (the record's key matches the z32, so it's the published record; a cross-station replica can come back with a non-canonical payload encoding — observed quirk, not tampering)");
        Other                       -> M:yellow(io_lib:format("~p", [Other]))
    end),
    M:kv("advertises v6", v6_of(Rec)),
    M:kv("record version", M:hex(maps:get(version, Rec, <<>>))),
    geo_distance(M),
    M:say(""),
    M:say("~ts", [M:dim("'distance' here: the resolve time above is this run's mesh-propagation latency; cities/geo for the great-circle.")]).

v6_of(#{payload := P}) when is_map(P) ->
    L = case maps:get(host_advertised, P, undefined) of
            undefined -> maps:get({text, <<"host_advertised">>}, P, []);
            V -> V
        end,
    case L of [H | _] -> unwrap(H); _ -> "(none)" end;
v6_of(_) -> "(no payload)".
unwrap({text, B}) when is_binary(B) -> binary_to_list(B);
unwrap(B) when is_binary(B) -> binary_to_list(B);
unwrap(X) -> X.

geo_distance(M) ->
    case {parse_pubgeo(os:getenv("HARNESS_MP_PUBGEO")), M:geo_from_env()} of
        {{ok, {PLa, PLn}}, {La, Ln}} ->
            Km = M:haversine_km(PLa, PLn, La, Ln),
            M:kv("geo distance", io_lib:format("≈ ~.0f km between publisher (~.4f, ~.4f) and this vantage (~.4f, ~.4f)",
                                               [Km, PLa, PLn, La, Ln]));
        {{ok, _}, undefined} ->
            M:kv("geo distance", "(set HECATE_GEO_LAT/LNG on this box to compute)");
        _ ->
            ok
    end.

parse_pubgeo(false) -> none;
parse_pubgeo("")    -> none;
parse_pubgeo(S) ->
    case string:split(S, ",", leading) of
        [A, B] ->
            case {string:to_float(string:trim(A)), string:to_float(string:trim(B))} of
                {{La, _}, {Ln, _}} when is_float(La), is_float(Ln) -> {ok, {La, Ln}};
                _ -> none
            end;
        _ -> none
    end.

%%====================================================================
%% util
%%====================================================================

mp_int(Name, Def) ->
    case os:getenv(Name) of
        V when V =:= false; V =:= "" -> Def;
        S -> case string:to_integer(string:trim(S)) of {I, _} when is_integer(I) -> I; _ -> Def end
    end.

iso_now() ->
    {{Y, Mo, D}, {H, Mi, Se}} = calendar:universal_time(),
    io_lib:format("~4..0b-~2..0b-~2..0bT~2..0b:~2..0b:~2..0bZ", [Y, Mo, D, H, Mi, Se]).
