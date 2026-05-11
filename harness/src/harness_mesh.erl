%%% @doc Shared helpers for the harness/ scripts: connect a transient macula
%%% V2 pool to the live relay fleet, query its status, ping/resolve stations,
%%% geo / haversine, hex / z32, and a tiny TTY-aware colour + table renderer.
%%%
%%% Runs in a bare `erl' node — no Erlang distribution (no epmd / no
%%% cluster-discovery flood), no `-heart', writes nothing to disk.
%%% @end
-module(harness_mesh).

-export([connect/0, connect/1, relays_from_env/0, status/1, z32/1, hex/1]).
-export([host_of_url/1, city_of_host/1, ping_rtt/1, resolve_v6/1]).
-export([geo_from_env/0, haversine_km/4]).
-export([tty/0, colour/2, c/2, bold/1, dim/1, red/1, green/1, yellow/1, cyan/1]).
-export([table/2, rule/0, rule/1, hdr/1, kv/2]).
-export([say/1, say/2]).

-define(DEFAULT_RELAYS, [
    <<"https://station-be-brussels.macula.io:4433">>,
    <<"https://station-be-antwerp.macula.io:4433">>,
    <<"https://station-be-hasselt.macula.io:4433">>
]).

%%====================================================================
%% Connect a transient pool to the live mesh
%%====================================================================

%% @equiv connect(#{})
connect() -> connect(#{}).

%% Returns `{ok, Pool}' once a station answers a harmless DHT probe, or
%% `{error, Reason}' on timeout. Opts: `relays' (list of url binaries),
%% `connect_budget_ms' (default 40000).
-spec connect(map()) -> {ok, pid()} | {error, term()}.
connect(Opts) ->
    {ok, _} = application:ensure_all_started(macula),
    Relays = maps:get(relays, Opts, relays_from_env()),
    {ok, Pool} = macula:connect(Relays, #{}),
    Budget = maps:get(connect_budget_ms, Opts, 40000),
    case wait_connected(Pool, Budget) of
        ok    -> {ok, Pool};
        Other -> Other
    end.

wait_connected(_Pool, Budget) when Budget =< 0 ->
    {error, mesh_not_connected_within_budget};
wait_connected(Pool, Budget) ->
    T0 = erlang:monotonic_time(millisecond),
    case catch macula:find_record(Pool, <<0:256>>) of
        {error, not_found} -> ok;
        {ok, _}            -> ok;
        _                  ->
            timer:sleep(1500),
            wait_connected(Pool, Budget - (erlang:monotonic_time(millisecond) - T0))
    end.

relays_from_env() ->
    case os:getenv("HARNESS_RELAYS") of
        V when V =:= false; V =:= "" -> ?DEFAULT_RELAYS;
        S -> [list_to_binary(string:trim(U))
              || U <- string:split(S, ",", all), string:trim(U) =/= ""]
    end.

%% @doc `macula:status/1' as a plain map (#{seeds, healthy_links,
%% failed_links, self_node_id, subscriptions}).
status(Pool) ->
    case catch macula:status(Pool) of
        {ok, S} when is_map(S) -> S;
        _ -> #{}
    end.

%%====================================================================
%% Identity / hex
%%====================================================================

z32(<<_:32/binary>> = Pubkey) -> macula_z32:encode(Pubkey);
z32(Other) when is_binary(Other) -> Other.

hex(Bin) when is_binary(Bin) -> string:lowercase(binary_to_list(binary:encode_hex(Bin)));
hex(_) -> "<n/a>".

%%====================================================================
%% Relay URL / hostname / city / ping / DNS
%%====================================================================

%% `<<"https://station-be-brussels.macula.io:4433">>' -> `"station-be-brussels.macula.io"'
host_of_url(Url) when is_binary(Url) -> host_of_url(binary_to_list(Url));
host_of_url(Url) ->
    S0 = re:replace(Url, "^[a-z]+://", "", [{return, list}]),
    hd(string:split(S0, ":", leading)).

%% `"station-be-brussels.macula.io"' -> `{"Brussels", "BE"}' (best effort).
%% Matches `(station|relay)-<cc>-<city-with-dashes>.…'.
city_of_host(Host) when is_binary(Host) -> city_of_host(binary_to_list(Host));
city_of_host(Host) ->
    case re:run(Host, "^(?:station|relay)-([a-z]{2})-([a-z0-9-]+)\\.",
                [{capture, [1, 2], list}]) of
        {match, [CC, RawCity]} ->
            City = titlecase(string:join(string:split(RawCity, "-", all), " ")),
            {City, string:uppercase(CC)};
        nomatch ->
            {"?", "??"}
    end.

titlecase([]) -> [];
titlecase([C | Rest]) -> [string:to_upper(C) | titlecase_rest(Rest)].
titlecase_rest([]) -> [];
titlecase_rest([$\s, C | Rest]) -> [$\s, string:to_upper(C) | titlecase_rest(Rest)];
titlecase_rest([C | Rest]) -> [C | titlecase_rest(Rest)].

%% `ping -6 -c 3 -W 2 <host>' -> `{ok, {MinMs, AvgMs}}' | `{error, unreachable}'.
ping_rtt(Host) when is_binary(Host) -> ping_rtt(binary_to_list(Host));
ping_rtt(Host) ->
    Cmd = "ping -6 -c 3 -W 2 -q " ++ shell_quote(Host) ++ " 2>&1",
    Out = os:cmd(Cmd),
    case re:run(Out, "= *([0-9.]+)/([0-9.]+)/", [{capture, [1, 2], list}]) of
        {match, [Min, Avg]} -> {ok, {to_f(Min), to_f(Avg)}};
        nomatch ->
            %% Some pings (or v4-only hosts) — retry without -6.
            Out2 = os:cmd("ping -c 3 -W 2 -q " ++ shell_quote(Host) ++ " 2>&1"),
            case re:run(Out2, "= *([0-9.]+)/([0-9.]+)/", [{capture, [1, 2], list}]) of
                {match, [Min, Avg]} -> {ok, {to_f(Min), to_f(Avg)}};
                nomatch             -> {error, unreachable}
            end
    end.

resolve_v6(Host) when is_binary(Host) -> resolve_v6(binary_to_list(Host));
resolve_v6(Host) ->
    case inet:getaddr(Host, inet6) of
        {ok, Addr} -> list_to_binary(inet:ntoa(Addr));
        _ ->
            case inet:getaddr(Host, inet) of
                {ok, A4} -> list_to_binary(inet:ntoa(A4));
                _        -> <<"(unresolved)">>
            end
    end.

shell_quote(S) -> "'" ++ lists:flatten(string:replace(S, "'", "'\\''", all)) ++ "'".
to_f(S) -> case string:to_float(S) of {F, _} -> F; _ -> case string:to_integer(S) of {I, _} -> float(I); _ -> 0.0 end end.

%%====================================================================
%% Geo
%%====================================================================

%% `{Lat, Lng}' from HECATE_GEO_LAT / HECATE_GEO_LNG, else `undefined'.
geo_from_env() ->
    case {env_f("HECATE_GEO_LAT"), env_f("HECATE_GEO_LNG")} of
        {Lat, Lng} when is_float(Lat), is_float(Lng) -> {Lat, Lng};
        _ -> undefined
    end.

env_f(Name) ->
    case os:getenv(Name) of
        V when V =:= false; V =:= "" -> undefined;
        S -> case string:to_float(string:trim(S)) of
                 {F, _} -> F;
                 _ -> case string:to_integer(string:trim(S)) of {I, _} -> float(I); _ -> undefined end
             end
    end.

%% Great-circle distance in km (Haversine).
haversine_km(Lat1, Lng1, Lat2, Lng2) ->
    R = 6371.0,
    P1 = deg2rad(Lat1), P2 = deg2rad(Lat2),
    DP = deg2rad(Lat2 - Lat1), DL = deg2rad(Lng2 - Lng1),
    A = math:sin(DP/2) * math:sin(DP/2)
        + math:cos(P1) * math:cos(P2) * math:sin(DL/2) * math:sin(DL/2),
    C = 2 * math:atan2(math:sqrt(A), math:sqrt(1 - A)),
    R * C.

deg2rad(D) -> D * math:pi() / 180.0.

%%====================================================================
%% TTY-aware colour + tiny table renderer
%%====================================================================

tty() -> case io:columns() of {ok, _} -> true; _ -> false end.

cols() -> case io:columns() of {ok, N} -> N; _ -> 80 end.

-define(ANSI, #{reset => "\033[0m", bold => "\033[1m", dim => "\033[2m",
                red => "\033[31m", green => "\033[32m", yellow => "\033[33m",
                blue => "\033[34m", magenta => "\033[35m", cyan => "\033[36m"}).

colour(Code, Str) -> c(Code, Str).
c(Code, Str) ->
    case tty() of
        true  -> [maps:get(Code, ?ANSI, ""), to_str(Str), maps:get(reset, ?ANSI)];
        false -> to_str(Str)
    end.
bold(S)   -> c(bold, S).
dim(S)    -> c(dim, S).
red(S)    -> c(red, S).
green(S)  -> c(green, S).
yellow(S) -> c(yellow, S).
cyan(S)   -> c(cyan, S).

to_str(S) when is_binary(S) -> binary_to_list(S);
to_str(S) when is_list(S)   -> S;
to_str(S) -> lists:flatten(io_lib:format("~p", [S])).

rule()   -> rule($─).
rule(Ch) -> say("~ts", [dim(lists:duplicate(min(cols(), 100), Ch))]).

hdr(Title) ->
    say(""),
    say("~ts", [bold([Title])]),
    rule().

kv(K, V) -> say("  ~ts ~ts", [dim(pad(to_str(K) ++ ":", 18)), to_str(V)]).

%% table(Headers :: [string()], Rows :: [[iodata()]]) — prints an aligned table.
%% Cells may carry ANSI; widths are measured on the *visible* length.
table(Headers, Rows) ->
    AllRows = [Headers | [[to_str(C) || C <- R] || R <- Rows]],
    NCols = length(Headers),
    Widths = [lists:max([vlen(lists:nth(I, R)) || R <- AllRows]) || I <- lists:seq(1, NCols)],
    say("  ~ts", [bold(render_row(Headers, Widths))]),
    say("  ~ts", [dim(render_row([lists:duplicate(W, $─) || W <- Widths], Widths))]),
    [say("  ~ts", [render_row([to_str(C) || C <- R], Widths)]) || R <- Rows],
    ok.

render_row(Cells, Widths) ->
    Padded = [pad_visible(to_str(C), W) || {C, W} <- lists:zip(Cells, Widths)],
    string:join(Padded, "  ").

%% visible length: count codepoints, skipping ANSI CSI sequences (ESC [ … m)
vlen(S) -> vlen_scan(lists:flatten(to_str(S)), 0).
vlen_scan([], N) -> N;
vlen_scan([27, $[ | Rest], N) -> vlen_scan(skip_csi(Rest), N);
vlen_scan([_ | Rest], N) -> vlen_scan(Rest, N + 1).
skip_csi([$m | Rest]) -> Rest;
skip_csi([_ | Rest])  -> skip_csi(Rest);
skip_csi([])          -> [].

pad_visible(S, W) ->
    L = vlen(S),
    case L >= W of true -> S; false -> [S, lists:duplicate(W - L, $\s)] end.
pad(S, W) when length(S) >= W -> S;
pad(S, W) -> S ++ lists:duplicate(W - length(S), $\s).

%%====================================================================
%% say
%%====================================================================

say(S) -> say(S, []).
say(Fmt, Args) -> io:format(Fmt ++ "~n", Args).
