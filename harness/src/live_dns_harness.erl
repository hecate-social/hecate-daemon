%%% @doc Live, no-stubs verification harness for the resolve_mesh_names
%%% Tier-1 mesh-native naming service + the serve_dns_over_mesh DNS
%%% wire bridge.
%%%
%%% Connects a real macula V2 client pool to the live relay/station
%%% fleet, publishes a freshly-generated `station_endpoint' record
%%% into the live DHT, then checks it resolves back through every
%%% layer of the stack:
%%%
%%%   (a) macula:find_record/2            — the raw DHT round-trip
%%%   (b) resolve_mesh_names_api:resolve/3 — Tier-1 resolve + the
%%%       self-rooted station trust verification + L4/L5 cache write
%%%   (c) serve_query:handle/3            — the DNS wire bridge, the
%%%       exact code path listen_udp/tcp/doh invoke, in-process:
%%%       RFC 1035 query bytes in → response bytes out, AAAA + SRV
%%%   (d) an external DNS client (nslookup) against the live
%%%       listen_udp socket on 127.0.0.1:<port> — true end-to-end
%%%       over the wire
%%%   (e) the two cache-invalidation PMs actually subscribed to the
%%%       live pool (verifies the integration wiring in commit
%%%       8be7a58 — hecate_mesh:get_client/0 + PM bootstrap)
%%%
%%% NOT a CT suite — it needs the live mesh + internet. Run it via
%%% `harness/run-live-dns-harness.sh'.
%%%
%%% Runs in a bare `erl' node — NO distribution (no `-name'/`-sname'
%%% → no epmd → no libcluster-discovery flood), NO `-heart' (no
%%% resurrection). Writes nothing to disk. The published
%%% station_endpoint is a transient test record under the RFC 3849
%%% documentation prefix (`2001:db8::/32') and self-expires (5 min
%%% TTL) after the harness exits — no cleanup needed.
%%% @end
-module(live_dns_harness).

-export([main/0, run/1]).

-define(DEFAULT_RELAYS, [
    <<"https://station-be-brussels.macula.io:4433">>,
    <<"https://station-be-antwerp.macula.io:4433">>,
    <<"https://station-be-hasselt.macula.io:4433">>
]).

%% RFC 3849 documentation prefix — unmistakably a test record.
-define(TEST_V6,   <<"2001:db8:dead:beef::1">>).
-define(TEST_V6_PREFIX, "2001:db8:dead:beef").
-define(TEST_PORT, 4433).
-define(TEST_ALPN, <<"macula/1">>).

%% RR / qtype numeric codes (we only need a handful).
-define(QT_A,    1).
-define(QT_AAAA, 28).
-define(QT_SRV,  33).

%%====================================================================
%% Entry point (called via `erl -eval live_dns_harness:main()')
%%====================================================================

main() ->
    Relays  = relays_from_env(),
    DnsPort = int_env("HARNESS_DNS_PORT", 5353),
    Keep    = int_env("HARNESS_KEEP_ALIVE_S", 0),
    Code = try run(#{relays => Relays, dns_port => DnsPort, keep_alive_s => Keep}) of
               pass -> 0;
               fail -> 1
           catch
               throw:Reason ->
                   io:format("~n*** HARNESS ABORTED: ~p~n", [Reason]), 3;
               Class:Err:Stack ->
                   io:format("~n*** HARNESS CRASHED: ~p:~p~n~p~n", [Class, Err, Stack]), 2
           end,
    halt(Code).

%%====================================================================
%% The run
%%====================================================================

run(Opts) ->
    say("=== live_dns_harness ==="),
    {ok, _} = application:ensure_all_started(macula),
    _ = application:load(resolve_mesh_names),
    _ = application:load(serve_dns_over_mesh),

    Relays = maps:get(relays, Opts),
    say("connecting V2 macula pool to ~b relay(s):", [length(Relays)]),
    [say("    ~s", [R]) || R <- Relays],
    {ok, Pool} = macula:connect(Relays, #{}),
    %% Publish the pool where the daemon's plumbing reads it: the DNS
    %% listeners fetch it per query via hecate_mesh:get_client/0, and
    %% the cache-invalidation PMs poll the same to bootstrap-subscribe.
    persistent_term:put({hecate_mesh_client, pool}, Pool),

    say("waiting for the pool to reach a connected station ..."),
    ok = wait_connected(Pool, 40000),
    say("pool connected: ~p", [Pool]),

    ReqPort = maps:get(dns_port, Opts, 5353),
    ok = application:set_env(serve_dns_over_mesh, udp_port, ReqPort),
    ok = application:set_env(serve_dns_over_mesh, tcp_port, ReqPort),
    {ok, _} = resolve_mesh_names_sup:start_link(),
    {ok, _} = serve_dns_over_mesh_sup:start_link(),
    DnsPort = wait_listener(2000),
    say("resolve_mesh_names + serve_dns_over_mesh started; listen_udp bound on 127.0.0.1:~p", [DnsPort]),

    %% Give the PMs a beat to run their first bootstrap_subscribe.
    timer:sleep(800),
    PmInfo = pm_subscription_info(),
    say("cache-invalidation PM subscriptions: ~p", [PmInfo]),

    %% ---- publish a fresh, self-signed station_endpoint ----
    KP = #{public := Pub} = macula_identity:generate(),
    Unsigned = macula_record:station_endpoint(Pub, ?TEST_PORT,
                   #{host_advertised => [?TEST_V6], alpn => ?TEST_ALPN}),
    Rec  = macula_record:sign(Unsigned, KP),
    Key  = macula_record:storage_key(Rec),
    Z32  = macula_z32:encode(Pub),
    Mri  = <<"mri:station:", Z32/binary>>,
    QName = <<Z32/binary, "._st.macula.io">>,
    say(""),
    say("published station identity:"),
    say("    pubkey (z32)  : ~s", [Z32]),
    say("    storage_key   : ~s", [hex(Key)]),
    say("    station MRI   : ~s", [Mri]),
    say("    dns name      : ~s", [QName]),
    say("    host_advertised: ~s   quic_port: ~b   alpn: ~s", [?TEST_V6, ?TEST_PORT, ?TEST_ALPN]),
    dbg("built record payload: ~p", [maps:get(payload, Rec, '<none>')]),
    ok = abort_unless_ok(put_retry(Pool, Rec, 8), {put_record_failed, '_'}),
    say("    macula:put_record/2 -> ok"),

    %% ---- (a) raw DHT round-trip ----
    A = case find_retry(Pool, Key, 8) of
            {ok, R2} ->
                dbg("round-tripped record payload: ~p", [maps:get(payload, R2, '<none>')]),
                {ok, (maps:get(key, R2, undefined) =:= Pub)
                     andalso (maps:get(type, R2, undefined) =:= maps:get(type, Rec))};
            FErr -> FErr
        end,
    say("(a) macula:find_record/2 round-trip          -> ~p", [A]),

    %% ---- (b) Tier-1 resolve + self-rooted trust verification ----
    B = resolve_mesh_names_api:resolve(Pool, Mri),
    Bv6 = case B of
              {ok, [VR | _]} ->
                  V = host_v6_of(VR),
                  say("(b) resolve_mesh_names_api:resolve/3        -> {ok, record_type=~p, signer=~s, host_v6=~p}",
                      [maps:get(record_type, VR, undefined),
                       short_hex(maps:get(signer_pubkey, VR, <<>>)), V]),
                  dbg("VR = ~p", [VR]),
                  V;
              Other ->
                  say("(b) resolve_mesh_names_api:resolve/3        -> ~p", [Other]),
                  undefined
          end,

    %% ---- (c) DNS wire bridge, in-process (the listen_udp code path) ----
    CA   = dns_probe(Pool, QName, ?QT_AAAA),
    CS   = dns_probe(Pool, QName, ?QT_SRV),
    say("(c) serve_query/3  AAAA ~s                   -> ~p", [QName, CA]),
    say("(c) serve_query/3  SRV  ~s                   -> ~p", [QName, CS]),

    %% ---- (d) external DNS client over the live UDP socket ----
    D = case DnsPort of
            undefined -> {skipped, no_listener};
            P -> external_dns(QName, P)
        end,
    say("(d) external DNS client (AAAA over :~p)      -> ~p", [DnsPort, D]),

    %% ---- verdict ----
    Checks = [
        {"raw DHT round-trip (find_record)",          A =:= {ok, true}},
        {"Tier-1 resolve returns the v6 record",      Bv6 =:= ?TEST_V6},
        {"DNS AAAA answer carries the v6 address",    CA =:= {ok, [?TEST_V6]}},
        {"DNS SRV answer is non-empty",               is_tuple_ok_nonempty(CS)},
        {"both cache PMs subscribed to the pool",     pms_subscribed_ok(PmInfo)},
        {"external DNS client returns the v6",        external_ok(D)}
    ],
    Verdict = report(Checks),

    case maps:get(keep_alive_s, Opts, 0) of
        0 -> ok;
        N when DnsPort =/= undefined ->
            say(""),
            say("keeping the listener up for ~b s — try, e.g.:", [N]),
            say("    nslookup -port=~p -type=AAAA ~s 127.0.0.1", [DnsPort, QName]),
            say("    doggo ~s @127.0.0.1:~p AAAA", [QName, DnsPort]),
            timer:sleep(N * 1000);
        _ -> ok
    end,
    Verdict.

%%====================================================================
%% Mesh-pool readiness
%%====================================================================

%% Retry a harmless DHT probe until the pool answers from a connected
%% station (i.e. returns `not_found' for a key that doesn't exist),
%% or the deadline expires.
wait_connected(_Pool, Budget) when Budget =< 0 ->
    throw(mesh_not_connected_within_budget);
wait_connected(Pool, Budget) ->
    T0 = erlang:monotonic_time(millisecond),
    case catch macula:find_record(Pool, <<0:256>>) of
        {error, not_found}             -> ok;
        {ok, _}                        -> ok;            %% (improbable, but: connected)
        {error, _Transient}            -> retry_connect(Pool, Budget, T0);
        {'EXIT', _}                    -> retry_connect(Pool, Budget, T0)
    end.

retry_connect(Pool, Budget, T0) ->
    timer:sleep(1500),
    Spent = erlang:monotonic_time(millisecond) - T0,
    wait_connected(Pool, Budget - Spent).

%%====================================================================
%% DNS-bridge listener readiness
%%====================================================================

wait_listener(Budget) when Budget =< 0 -> undefined;
wait_listener(Budget) ->
    case catch listen_udp:port() of
        {ok, P}   -> P;
        _ -> timer:sleep(150), wait_listener(Budget - 150)
    end.

%%====================================================================
%% Cache-invalidation PMs — did they bootstrap-subscribe?
%%====================================================================

pm_subscription_info() ->
    [{Mod, pm_state(Mod)} ||
        Mod <- [on_record_observed_invalidate_cache,
                on_realm_directory_changed_warm_cache]].

pm_state(Mod) ->
    case whereis(Mod) of
        undefined -> not_running;
        _ ->
            case catch sys:get_state(Mod) of
                #{pool := Pool, subs := Subs} ->
                    #{pool => Pool, n_subs => length(Subs)};
                Other -> {unexpected_state, Other}
            end
    end.

pms_subscribed_ok(Info) ->
    lists:all(fun({_Mod, #{pool := P, n_subs := N}}) when is_pid(P), N >= 1 -> true;
                 (_) -> false
              end, Info).

%%====================================================================
%% Publish-retry / find-retry over the cross-station-flaky DHT
%%====================================================================

put_retry(_Pool, _Rec, 0) -> {error, exhausted};
put_retry(Pool, Rec, N) ->
    case macula:put_record(Pool, Rec) of
        ok -> ok;
        {error, _Why} -> timer:sleep(2000), put_retry(Pool, Rec, N - 1)
    end.

find_retry(_Pool, _Key, 0) -> {error, exhausted};
find_retry(Pool, Key, N) ->
    case macula:find_record(Pool, Key) of
        {ok, _} = Ok       -> Ok;
        {error, not_found} -> timer:sleep(1500), find_retry(Pool, Key, N - 1);
        {error, timeout}   -> timer:sleep(1500), find_retry(Pool, Key, N - 1);
        {error, _} = E     -> E
    end.

%%====================================================================
%% Synthetic DNS query through serve_query/3 (the listen_udp path)
%%====================================================================

%% Build an RFC 1035 query, hand it to serve_query:handle/3 (exactly
%% what listen_udp does), decode the answer section. Returns
%% `{ok, [<<"addr">>, ...]}' for the answered RRs of the queried type,
%% `{rcode, Atom}' on a non-NOERROR response, or `{error, _}'.
dns_probe(Pool, QName, QType) ->
    Query = build_query(QName, QType),
    case serve_query:handle(Pool, Query, #{}) of
        {ok, Resp} -> decode_answers(Resp, QType);
        drop       -> {error, dropped}
    end.

build_query(QName, QType) ->
    Id = rand:uniform(65535),
    %% Flags: QR=0, Opcode=0, RD=1 -> 0x0100. QDCOUNT=1, rest 0.
    Header = <<Id:16, 16#0100:16, 1:16, 0:16, 0:16, 0:16>>,
    Question = <<(compose_response:encode_name(QName))/binary, QType:16, 1:16>>,
    <<Header/binary, Question/binary>>.

%% Decode the answer section: returns the rdata of the RRs matching
%% QType (AAAA -> v6 string, SRV -> "<prio> <weight> <port> <target>",
%% A -> v4 string), or {rcode, _} for a non-NOERROR reply.
decode_answers(<<_Id:16, Flags:16, QD:16, AN:16, _NS:16, _AR:16, Body/binary>>, QType) ->
    case Flags band 16#000F of
        0 ->
            AfterQ = skip_questions(Body, QD),
            {ok, rrs_of_type(AfterQ, AN, QType, [])};
        Rcode ->
            {rcode, rcode_atom(Rcode)}
    end;
decode_answers(_, _) ->
    {error, malformed_response}.

skip_questions(Bin, 0) -> Bin;
skip_questions(Bin, N) ->
    {_Name, Rest} = skip_dns_name(Bin),
    <<_QType:16, _QClass:16, Rest2/binary>> = Rest,
    skip_questions(Rest2, N - 1).

rrs_of_type(_Bin, 0, _QType, Acc) -> lists:reverse(Acc);
rrs_of_type(Bin, N, QType, Acc) ->
    {_Name, AfterName} = skip_dns_name(Bin),
    <<Type:16, _Class:16, _Ttl:32, RdLen:16, Rdata:RdLen/binary, Rest/binary>> = AfterName,
    Acc2 = case Type =:= QType of
               true  -> [decode_rdata(QType, Rdata) | Acc];
               false -> Acc
           end,
    rrs_of_type(Rest, N - 1, QType, Acc2).

%% Skip a DNS name (handles compression pointers, length-prefixed
%% labels, and the zero terminator). We don't need the decoded name.
skip_dns_name(<<3:2, _Ptr:14, Rest/binary>>) -> {ptr, Rest};
skip_dns_name(<<0, Rest/binary>>)            -> {<<>>, Rest};
skip_dns_name(<<Len:8, _Label:Len/binary, Rest/binary>>) when Len < 64 ->
    skip_dns_name(Rest).

decode_rdata(?QT_AAAA, <<A:16,B:16,C:16,D:16,E:16,F:16,G:16,H:16>>) ->
    list_to_binary(inet:ntoa({A,B,C,D,E,F,G,H}));
decode_rdata(?QT_A, <<A,B,C,D>>) ->
    list_to_binary(inet:ntoa({A,B,C,D}));
decode_rdata(?QT_SRV, <<Prio:16, Weight:16, Port:16, Target/binary>>) ->
    iolist_to_binary([integer_to_list(Prio), " ", integer_to_list(Weight), " ",
                      integer_to_list(Port), " (target ", integer_to_list(byte_size(Target)),
                      " bytes)"]);
decode_rdata(_, Raw) ->
    Raw.

rcode_atom(1) -> formerr;
rcode_atom(2) -> servfail;
rcode_atom(3) -> nxdomain;
rcode_atom(4) -> notimp;
rcode_atom(5) -> refused;
rcode_atom(N) -> {rcode, N}.

%%====================================================================
%% External DNS client over the live UDP socket
%%====================================================================

external_dns(QName, Port) ->
    case os:find_executable("nslookup") of
        false -> {skipped, no_nslookup};
        _ ->
            Cmd = "nslookup -port=" ++ integer_to_list(Port) ++ " -type=AAAA -timeout=3 "
                  ++ binary_to_list(QName) ++ " 127.0.0.1 2>&1",
            Out = os:cmd(Cmd),
            case string:find(Out, ?TEST_V6_PREFIX) of
                nomatch -> {error, {no_match, trim_out(Out)}};
                _       -> {ok, found}
            end
    end.

trim_out(S) -> string:trim(lists:flatten(string:replace(S, "\n", " | ", all))).

%%====================================================================
%% Verified-record helpers
%%====================================================================

%% Read host_advertised tolerantly. macula's CBOR decode is
%% non-deterministic about payload key form — it `binary_to_existing_atom's
%% text-string keys, so `<<"host_advertised">>' comes back as the atom
%% `host_advertised' (the atom pre-exists) while `<<"quic_port">>' stays
%% `{text, <<"quic_port">>}' (no such atom). Try atom → {text,bin} → bare bin.
host_v6_of(#{payload := P}) when is_map(P) ->
    case payload_field(P, host_advertised, <<"host_advertised">>) of
        [V6 | _] -> unwrap_text(V6);
        _        -> undefined
    end;
host_v6_of(_) -> undefined.

payload_field(P, AtomKey, BinKey) ->
    case maps:get(AtomKey, P, '$absent') of
        '$absent' ->
            case maps:get({text, BinKey}, P, '$absent') of
                '$absent' -> maps:get(BinKey, P, undefined);
                V -> V
            end;
        V -> V
    end.

unwrap_text({text, B}) when is_binary(B) -> B;
unwrap_text(B) -> B.

%%====================================================================
%% Report
%%====================================================================

report(Checks) ->
    say(""),
    say("---------------------------------------------------------------"),
    AllPass = lists:foldl(
        fun({Label, Bool}, Acc) ->
            {Mark, Pass} = case Bool of
                               true  -> {"PASS", true};
                               false -> {"FAIL", false};
                               skip  -> {"skip", true};
                               _     -> {"FAIL", false}
                           end,
            say("  [~s]  ~s", [Mark, Label]),
            Acc andalso Pass
        end, true, Checks),
    say("---------------------------------------------------------------"),
    case AllPass of
        true  -> say("  VERDICT: PASS — resolve_mesh_names + serve_dns_over_mesh verified live against the mesh, no stubs."), pass;
        false -> say("  VERDICT: FAIL — see the per-check lines above."), fail
    end.

%%====================================================================
%% small util
%%====================================================================

abort_unless_ok(ok, _Reason) -> ok;
abort_unless_ok(Other, Reason) -> throw({Reason, Other}).

is_tuple_ok_nonempty({ok, L}) when is_list(L), L =/= [] -> true;
is_tuple_ok_nonempty(_) -> false.

external_ok({ok, _})       -> true;
external_ok({skipped, _})  -> skip;
external_ok(_)             -> false.

relays_from_env() ->
    case os:getenv("HARNESS_RELAYS") of
        false -> ?DEFAULT_RELAYS;
        ""    -> ?DEFAULT_RELAYS;
        S     -> [list_to_binary(string:trim(U))
                  || U <- string:split(S, ",", all), string:trim(U) =/= ""]
    end.

int_env(Name, Default) ->
    case os:getenv(Name) of
        false -> Default;
        ""    -> Default;
        S     -> case string:to_integer(string:trim(S)) of
                     {N, _} when is_integer(N) -> N;
                     _ -> Default
                 end
    end.

hex(Bin) -> string:lowercase(binary_to_list(binary:encode_hex(Bin))).
short_hex(<<>>) -> "<none>";
short_hex(Bin) when is_binary(Bin) ->
    H = hex(Bin),
    lists:sublist(H, 16) ++ "...".

say(Fmt) -> say(Fmt, []).
say(Fmt, Args) -> io:format("[harness] " ++ Fmt ++ "~n", Args).

%% Verbose dump — only when HARNESS_DEBUG is set.
dbg(Fmt, Args) ->
    case os:getenv("HARNESS_DEBUG") of
        V when V =:= false; V =:= "" -> ok;
        _ -> io:format("[harness] [debug] " ++ Fmt ++ "~n", Args)
    end.
