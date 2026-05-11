%%% @doc A narrated walk-through of the mesh-naming stack — good for a screencast
%%% or showing someone what this thing does. Same machinery as the harness, but
%%% paced and story-shaped:
%%%
%%%   1. connect to the live station fleet (show who, how far)
%%%   2. mint a fresh station identity
%%%   3. publish its endpoint into the mesh DHT
%%%   4. ask the mesh to resolve it back (Tier-1, with trust verification)
%%%   5. ask for it over plain DNS — `nslookup <z32>._st.macula.io` against the
%%%      daemon's listener — and watch the AAAA answer come back
%%%
%%% A name went into the mesh and came back out as a DNS record. Test record
%%% only (RFC 3849 doc prefix, ~5-min TTL). Bare erl: no dist, no -heart, no
%%% disk writes.
%%% @end
-module(mesh_demo).
-export([main/0]).

-define(TEST_V6,   <<"2001:db8:dead:beef::1">>).
-define(TEST_PORT, 4433).
-define(TEST_ALPN, <<"macula/1">>).

main() ->
    M = harness_mesh,
    Fast = os:getenv("HARNESS_DEMO_FAST") =:= "1",
    Keep = mp_int("HARNESS_DEMO_KEEP", 0),
    title(M, "Macula mesh naming — a quick tour"),
    beat(M, Fast, "What you'll see: a fresh name published into a Kademlia DHT of "
                  "PKARR-style signed records, then resolved back — first as the "
                  "mesh-native API gives it, then as an ordinary DNS lookup."),

    %% 1 — connect ------------------------------------------------------
    step(M, 1, "Connecting to the live station fleet"),
    Relays = M:relays_from_env(),
    {ok, Pool} = M:connect(#{relays => Relays, connect_budget_ms => 40000}),
    persistent_term:put({hecate_mesh_client, pool}, Pool),
    _ = application:load(resolve_mesh_names),
    _ = application:load(serve_dns_over_mesh),
    St = M:status(Pool),
    M:say("  ~ts connected — pool identity ~ts, ~ts healthy link(s)",
          [M:green("✓"), M:cyan(binary_to_list(M:z32(maps:get(self_node_id, St, <<>>)))),
           M:green(integer_to_list(maps:get(healthy_links, St, 0)))]),
    M:say(""),
    M:say("  ~ts", [M:dim("pinging the seeds …")]),
    [begin
         H = M:host_of_url(U), {C, CC} = M:city_of_host(H),
         R = case M:ping_rtt(H) of {ok, {_, Av}} -> io_lib:format("~.1f ms", [Av]); _ -> "unreachable" end,
         M:say("    ~-30ts  ~-15ts  ~ts", [H, C ++ ", " ++ CC, M:dim(R)])
     end || U <- Relays],
    pause(Fast),

    %% 2 — mint identity ----------------------------------------------
    step(M, 2, "Minting a fresh station identity"),
    KP = #{public := Pub} = macula_identity:generate(),
    Z32 = macula_z32:encode(Pub),
    QName = <<Z32/binary, "._st.macula.io">>,
    M:say("  pubkey      ~ts", [M:cyan(binary_to_list(Z32))]),
    M:say("  → MRI       ~ts", [M:cyan("mri:station:" ++ binary_to_list(Z32))]),
    M:say("  → DNS name  ~ts", [M:cyan(binary_to_list(QName))]),
    M:say("  ~ts", [M:dim("(self-rooted — the pubkey IS the name; no realm or CA needed)")]),
    pause(Fast),

    %% 3 — publish ----------------------------------------------------
    step(M, 3, "Publishing its endpoint into the mesh DHT"),
    Rec = macula_record:sign(
            macula_record:station_endpoint(Pub, ?TEST_PORT,
                #{host_advertised => [?TEST_V6], alpn => ?TEST_ALPN}), KP),
    Key = macula_record:storage_key(Rec),
    M:say("  signed station_endpoint  ·  advertises AAAA ~ts, SRV port ~b, alpn ~ts",
          [?TEST_V6, ?TEST_PORT, ?TEST_ALPN]),
    M:say("  storage key  ~ts", [M:dim(M:hex(Key))]),
    ok = put_retry(Pool, Rec, 8),
    M:say("  ~ts macula:put_record/2 — stored, replicating to the K-nearest peers", [M:green("✓")]),
    pause(Fast),

    %% 4 — resolve (Tier-1) -------------------------------------------
    step(M, 4, "Asking the mesh to resolve it back  (Tier-1, with trust verification)"),
    {ok, _} = resolve_mesh_names_sup:start_link(),
    Mri = <<"mri:station:", Z32/binary>>,
    case resolve_mesh_names_api:resolve(Pool, Mri) of
        {ok, [VR | _]} ->
            M:say("  ~ts resolve_mesh_names_api:resolve(~ts)", [M:green("✓"), M:cyan(binary_to_list(Mri))]),
            M:say("    → record_type ~p, self-signed by the advertised key, host_v6 = ~ts",
                  [maps:get(record_type, VR, undefined), M:green(unwrap(v6_of(VR)))]);
        Other ->
            M:say("  ~ts resolve came back ~p", [M:red("×"), Other])
    end,
    pause(Fast),

    %% 5 — over DNS ---------------------------------------------------
    step(M, 5, "Now the same name, over ordinary DNS"),
    ok = application:set_env(serve_dns_over_mesh, udp_port, 5353),
    ok = application:set_env(serve_dns_over_mesh, tcp_port, 5353),
    {ok, _} = serve_dns_over_mesh_sup:start_link(),
    Port = wait_listener(2000),
    M:say("  the daemon's DNS-over-mesh listener is up on ~ts", [M:cyan("127.0.0.1:" ++ integer_to_list(Port))]),
    M:say("  running:  ~ts", [M:cyan(io_lib:format("nslookup -port=~p -type=AAAA ~s 127.0.0.1", [Port, QName]))]),
    pause(Fast),
    {ok, Bin} = inet:gethostname(),
    _ = Bin,
    Out = os:cmd(io_lib:format("nslookup -port=~p -type=AAAA -timeout=3 ~s 127.0.0.1 2>&1", [Port, QName])),
    [M:say("    ~ts", [M:dim(L)]) || L <- string:split(string:trim(Out), "\n", all)],
    Got = string:find(Out, "2001:db8:dead:beef") =/= nomatch,
    M:say(""),
    case Got of
        true  -> M:say("  ~ts the mesh answered the DNS query with ~ts", [M:green("✓"), M:green(binary_to_list(?TEST_V6))]);
        false -> M:say("  ~ts no AAAA in the answer (mesh blip — try again)", [M:red("×")])
    end,

    %% wrap ------------------------------------------------------------
    M:say(""),
    M:rule($═),
    M:say("  ~ts", [M:bold("A name went into the mesh — a Kademlia DHT of signed records — and came back out as a DNS record.")]),
    M:say("  ~ts", [M:dim("No ICANN root, no CA, no central directory. The pubkey is the root of trust.")]),
    case Keep > 0 of
        true ->
            M:say(""),
            M:say("  ~ts", [M:dim(io_lib:format("listener stays up ~b s — try it yourself:", [Keep]))]),
            M:say("    ~ts", [M:cyan(io_lib:format("nslookup -port=~p -type=AAAA ~s 127.0.0.1", [Port, QName]))]),
            M:say("    ~ts", [M:cyan(io_lib:format("nslookup -port=~p -type=SRV ~s 127.0.0.1",  [Port, QName]))]),
            timer:sleep(Keep * 1000);
        false -> ok
    end,
    halt(case Got of true -> 0; false -> 1 end).

%%--------------------------------------------------------------------

title(M, T) ->
    M:say(""),
    M:rule($═),
    M:say("  ~ts", [M:bold(T)]),
    M:rule($═).

step(M, N, T) ->
    M:say(""),
    M:say("~ts  ~ts", [M:bold("[" ++ integer_to_list(N) ++ "]"), M:bold(T)]),
    M:rule().

beat(M, Fast, Text) ->
    M:say(""),
    M:say("  ~ts", [M:dim(Text)]),
    pause(Fast).

pause(true)  -> ok;
pause(false) -> timer:sleep(1200).

put_retry(_Pool, _Rec, 0) -> {error, exhausted};
put_retry(Pool, Rec, N) ->
    case macula:put_record(Pool, Rec) of
        ok -> ok;
        {error, _} -> timer:sleep(2000), put_retry(Pool, Rec, N - 1)
    end.

wait_listener(B) when B =< 0 -> 5353;
wait_listener(B) -> case catch listen_udp:port() of {ok, P} -> P; _ -> timer:sleep(150), wait_listener(B - 150) end.

v6_of(#{payload := P}) when is_map(P) ->
    L = case maps:get(host_advertised, P, undefined) of
            undefined -> maps:get({text, <<"host_advertised">>}, P, []);
            V -> V
        end,
    case L of [H | _] -> H; _ -> "(none)" end;
v6_of(_) -> "(no payload)".
unwrap({text, B}) when is_binary(B) -> binary_to_list(B);
unwrap(B) when is_binary(B) -> binary_to_list(B);
unwrap(X) -> X.

mp_int(Name, Def) ->
    case os:getenv(Name) of
        V when V =:= false; V =:= "" -> Def;
        S -> case string:to_integer(string:trim(S)) of {I, _} when is_integer(I) -> I; _ -> Def end
    end.
