%%% @doc "mesh weather" — what the Macula mesh looks like from *this* vantage
%%% point: the pool's identity, this machine's geo, and the stations it seeds
%%% from with their city, IPv6, and round-trip latency (the honest "distance").
%%%
%%% Run it here, then `ssh' (or `scp' + run) it on another box, and eyeball the
%%% two vantage points side by side. NOT a verification tool — no PASS/FAIL.
%%%
%%% Note: a transient pool only knows the *seeds* it was handed (default the
%%% be-* fleet; override with HARNESS_RELAYS=url,url,...). The full world-wide
%%% relay fleet w/ geo-distances lives in `macula_relay_discovery' on a
%%% connected daemon — not wired into this transient pool yet (TODO).
%%% @end
-module(mesh_weather).
-export([main/0]).

main() ->
    M = harness_mesh,
    M:say("~ts", [M:bold("mesh weather  —  the mesh from this vantage point")]),
    M:say("~ts", [M:dim(io_lib:format("~s", [calendar_now()]))]),
    Relays = M:relays_from_env(),
    M:say("~ts", [M:dim(io_lib:format("seeds: ~ts", [string:join([binary_to_list(R) || R <- Relays], "  ")]))]),
    case M:connect(#{relays => Relays, connect_budget_ms => 40000}) of
        {ok, Pool} ->
            vantage(M, Pool, Relays),
            stations(M, Pool, Relays),
            M:say(""),
            halt(0);
        {error, Why} ->
            M:say("~ts ~p", [M:red("× could not reach the mesh:"), Why]),
            M:say("~ts", [M:dim("  (no station answered a DHT probe within the budget — check IPv6 connectivity to the seed hosts)")]),
            halt(1)
    end.

%%--------------------------------------------------------------------

vantage(M, Pool, Relays) ->
    S = M:status(Pool),
    {ok, Host} = inet:gethostname(),
    SelfId = maps:get(self_node_id, S, <<>>),
    Healthy = maps:get(healthy_links, S, 0),
    Failed  = maps:get(failed_links, S, 0),
    NSeeds  = length(maps:get(seeds, S, Relays)),
    M:hdr("vantage"),
    M:kv("host", Host),
    M:kv("pool identity (z32)", M:z32(SelfId)),
    M:kv("geo", geo_str(M:geo_from_env())),
    M:kv("pool links", io_lib:format("~ts healthy / ~ts failed  (of ~b seed station~ts)",
                                     [link_n(M, Healthy, healthy), link_n(M, Failed, failed),
                                      NSeeds, plural(NSeeds)])).

link_n(M, 0, healthy) -> M:red("0");
link_n(M, N, healthy) -> M:green(integer_to_list(N));
link_n(_M, 0, failed) -> "0";
link_n(M, N, failed)  -> M:red(integer_to_list(N)).

geo_str(undefined) -> "(not set — export HECATE_GEO_LAT / HECATE_GEO_LNG / HECATE_GEO_CITY)";
geo_str({Lat, Lng}) ->
    City = case os:getenv("HECATE_GEO_CITY") of false -> ""; "" -> ""; C -> C ++ " · " end,
    io_lib:format("~s~.4f, ~.4f", [City, Lat, Lng]).

%%--------------------------------------------------------------------

stations(M, Pool, Relays) ->
    Seeds = case maps:get(seeds, M:status(Pool), []) of [] -> Relays; Sd -> Sd end,
    M:say(""),
    M:say("~ts", [M:dim("pinging stations …")]),
    Rows = [station_row(M, U) || U <- Seeds],
    Sorted = lists:sort(fun(A, B) -> sort_key(A) =< sort_key(B) end, Rows),
    M:hdr("stations this vantage seeds from"),
    M:table(["#", "host", "city", "ipv6", "ping  min / avg (ms)", "reach"],
            [render(M, I, R) || {I, R} <- lists:zip(lists:seq(1, length(Sorted)), Sorted)]),
    M:say(""),
    M:say("~ts", [M:dim("ping RTT is the network 'distance' to each station. Cities are parsed from the host name.")]).

%% station_row -> {Host, City, CC, V6, PingResult}
station_row(M, Url) ->
    Host = M:host_of_url(Url),
    {City, CC} = M:city_of_host(Host),
    {list_to_binary(Host), City, CC, M:resolve_v6(Host), M:ping_rtt(Host)}.

sort_key({_, _, _, _, {ok, {_, Avg}}}) -> Avg;
sort_key({_, _, _, _, {error, _}})     -> 1.0e9.

render(M, I, {Host, City, CC, V6, Ping}) ->
    {PingCell, Reach} = case Ping of
        {ok, {Min, Avg}} ->
            {io_lib:format("~6.1f / ~6.1f", [Min, Avg]), M:green("up")};
        {error, _} ->
            {M:dim("       —"), M:red("unreachable")}
    end,
    [integer_to_list(I), binary_to_list(Host),
     City ++ ", " ++ CC, binary_to_list(V6), lists:flatten(PingCell), Reach].

plural(1) -> ""; plural(_) -> "s".

calendar_now() ->
    {{Y, Mo, D}, {H, Mi, _}} = calendar:universal_time(),
    io_lib:format("~4..0b-~2..0b-~2..0b ~2..0b:~2..0bZ", [Y, Mo, D, H, Mi]).
