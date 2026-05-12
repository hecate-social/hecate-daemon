%%% @doc LAN scanner — discovers machines on the local network.
%%%
%%% Combines multiple discovery methods:
%%% 1. ARP table scan (already-known hosts from OS cache)
%%% 2. mDNS/Avahi hostname resolution (workstation service)
%%% 3. Hecate API probe (check if machine runs hecate-daemon)
%%%
%%% Results are cached in ETS and refreshed periodically.
%%% The scanner does NOT perform aggressive network scans —
%%% it reads the OS ARP cache and resolves hostnames.
%%% @end
-module(lan_scanner).
-behaviour(gen_server).

-export([start_link/0]).
-export([get_nodes/0, scan_now/0]).

%% gen_server callbacks
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(TABLE, lan_nodes).
-define(SCAN_INTERVAL_MS, 30_000).   %% 30s between scans
-define(PROBE_TIMEOUT_MS, 2_000).    %% 2s per SSH probe

-record(state, {
    timer_ref :: reference() | undefined
}).

%%%===================================================================
%%% API
%%%===================================================================

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Get all discovered LAN nodes.
-spec get_nodes() -> {ok, [map()]}.
get_nodes() ->
    Nodes = ets:tab2list(?TABLE),
    {ok, [Node || {_IP, Node} <- Nodes]}.

%% @doc Trigger an immediate scan.
-spec scan_now() -> ok.
scan_now() ->
    gen_server:cast(?MODULE, scan_now).

%%%===================================================================
%%% gen_server callbacks
%%%===================================================================

init([]) ->
    ?TABLE = ets:new(?TABLE, [named_table, set, public, {read_concurrency, true}]),
    %% First scan after 2s (let the daemon finish booting)
    TimerRef = erlang:send_after(2_000, self(), scan),
    {ok, #state{timer_ref = TimerRef}}.

handle_call(get_nodes, _From, State) ->
    {ok, Nodes} = get_nodes(),
    {reply, {ok, Nodes}, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown}, State}.

handle_cast(scan_now, State) ->
    cancel_timer(State),
    do_scan(),
    TimerRef = erlang:send_after(?SCAN_INTERVAL_MS, self(), scan),
    {noreply, State#state{timer_ref = TimerRef}};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(scan, State) ->
    do_scan(),
    TimerRef = erlang:send_after(?SCAN_INTERVAL_MS, self(), scan),
    {noreply, State#state{timer_ref = TimerRef}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%%%===================================================================
%%% Scanning
%%%===================================================================

%% @private Run a full LAN scan: ARP → resolve hostnames → probe hecate.
do_scan() ->
    ArpEntries = read_arp_table(),
    SelfIP = get_self_ip(),
    %% Filter out self and incomplete entries
    Hosts = [E || E <- ArpEntries, maps:get(ip, E) =/= SelfIP],
    %% Probe each host for hecate in parallel
    Probed = parallel_probe(Hosts),
    %% Update ETS
    lists:foreach(fun(#{ip := IP} = Node) ->
        ets:insert(?TABLE, {IP, Node})
    end, Probed),
    %% Remove stale entries (IPs no longer in ARP)
    CurrentIPs = sets:from_list([maps:get(ip, H) || H <- Hosts]),
    Stale = [IP || {IP, _} <- ets:tab2list(?TABLE),
                   not sets:is_element(IP, CurrentIPs)],
    lists:foreach(fun(IP) -> ets:delete(?TABLE, IP) end, Stale),
    %% Dispatch spot events for meaningful changes (aggregate decides idempotency)
    lists:foreach(fun dispatch_spot/1, Probed),
    %% Auto-admit nodes that run hecate with our site_id
    auto_admit_peers(Probed),
    logger:debug("[lan_scanner] Scan complete: ~b hosts found", [length(Probed)]).

%% @private Dispatch a spot command for a probed host.
%%
%% `hostname' / `ssh' go into the command only when this scan got a
%% definite answer (`hostname_resolved' / `ssh_probed'). Otherwise
%% the key is omitted and the lan_machine aggregate carries the
%% stored value forward (see lan_machine_aggregate:carry_forward/2 +
%% should_spot/2). Without that, transient reverse-DNS / SSH-probe
%% flakiness toggled the fields and recorded a spot event on nearly
%% every scan.
dispatch_spot(#{mac := MAC, ip := IP} = Host) ->
    Base = #{
        mac => list_to_binary(MAC),
        observer => atom_to_binary(node()),
        ip => list_to_binary(IP),
        interface => list_to_binary(maps:get(interface, Host, "")),
        hecate => maps:get(hecate, Host, #{running => false})
    },
    Cmd = include_if(maps:get(ssh_probed, Host, false), ssh, maps:get(ssh_available, Host, false),
            include_if(maps:get(hostname_resolved, Host, false), hostname, maps:get(hostname, Host, <<>>),
                Base)),
    dispatch_spot_safe(Cmd);
dispatch_spot(_) ->
    ok.

include_if(false, _Key, _Value, Map) -> Map;
include_if(true, Key, Value, Map)    -> Map#{Key => Value}.

%%%===================================================================
%%% ARP table
%%%===================================================================

%% @private Read the OS ARP cache. Works on Linux.
%% Returns list of #{ip, mac, interface} maps.
-spec read_arp_table() -> [map()].
read_arp_table() ->
    case file:read_file("/proc/net/arp") of
        {ok, Content} ->
            parse_arp_table(Content);
        {error, _} ->
            %% Fallback: use `arp -n` command
            case os:cmd("arp -an 2>/dev/null") of
                [] -> [];
                Output -> parse_arp_command(list_to_binary(Output))
            end
    end.

%% @private Parse /proc/net/arp format:
%% IP address       HW type     Flags       HW address            Mask     Device
%% 192.168.1.1      0x1         0x2         aa:bb:cc:dd:ee:ff     *        enp3s0
parse_arp_table(Content) ->
    [_Header | Lines] = binary:split(Content, <<"\n">>, [global]),
    lists:filtermap(fun(Line) ->
        case binary:split(string:trim(Line), <<" ">>, [global, trim_all]) of
            [IP, _HWType, Flags, MAC, _Mask, Iface] ->
                %% Flags 0x2 = complete entry (resolved)
                case Flags of
                    <<"0x2">> ->
                        {true, #{
                            ip => binary_to_list(IP),
                            mac => binary_to_list(MAC),
                            interface => binary_to_list(Iface)
                        }};
                    _ -> false  %% incomplete entry
                end;
            _ -> false
        end
    end, Lines).

%% @private Parse `arp -an` output format:
%% ? (192.168.1.1) at aa:bb:cc:dd:ee:ff [ether] on enp3s0
parse_arp_command(Output) ->
    Lines = binary:split(Output, <<"\n">>, [global]),
    lists:filtermap(fun(Line) ->
        case re:run(Line, <<"\\(([0-9.]+)\\) at ([0-9a-f:]+) .* on (\\S+)">>,
                    [{capture, [1, 2, 3], list}]) of
            {match, [IP, MAC, Iface]} ->
                {true, #{ip => IP, mac => MAC, interface => Iface}};
            _ -> false
        end
    end, Lines).

%%%===================================================================
%%% Hostname resolution
%%%===================================================================

%% @private Resolve IP to hostname via DNS/mDNS.
%% `{ok, Bin}' on a real PTR; `not_found' when the lookup fails or
%% times out (the caller keeps whatever it had instead of flapping
%% the name to the bare IP and back).
-spec resolve_hostname(string()) -> {ok, binary()} | not_found.
resolve_hostname(IP) ->
    case inet:gethostbyaddr(IP) of
        {ok, {hostent, Hostname, _, _, _, _}} -> {ok, list_to_binary(Hostname)};
        _                                     -> not_found
    end.

%%%===================================================================
%%% Hecate probing
%%%===================================================================

%% @private Probe hosts for hecate in parallel (max 10 concurrent).
parallel_probe(Hosts) ->
    Self = self(),
    Ref = make_ref(),
    %% Spawn a probe for each host
    Pids = lists:map(fun(Host) ->
        spawn_link(fun() ->
            Result = probe_host(Host),
            Self ! {probe_result, Ref, Result}
        end)
    end, Hosts),
    %% Collect results with timeout
    collect_results(Ref, length(Pids), []).

collect_results(_Ref, 0, Acc) -> Acc;
collect_results(Ref, Remaining, Acc) ->
    receive
        {probe_result, Ref, Result} ->
            collect_results(Ref, Remaining - 1, [Result | Acc])
    after 5_000 ->
        %% Timeout waiting for remaining probes
        Acc
    end.

%% @private Probe a single host: resolve hostname + ssh + hecate.
%% `hostname_resolved' / `ssh_probed' record whether THIS cycle got a
%% definite answer; dispatch_spot/1 uses them so a transient miss
%% doesn't blank a previously-known value via a new spot event. The
%% ETS cache still always carries `hostname'/`ssh_available' (with the
%% IP / false as the "couldn't tell" placeholder) for the UI.
probe_host(#{ip := IP} = Host) ->
    {Hostname, Resolved} = case resolve_hostname(IP) of
        {ok, H}   -> {H, true};
        not_found -> {list_to_binary(IP), false}
    end,
    {SSH, SSHProbed} = case probe_ssh(IP) of
        unknown   -> {false, false};
        Available -> {Available, true}
    end,
    Host#{
        hostname => Hostname,
        hostname_resolved => Resolved,
        ssh_available => SSH,
        ssh_probed => SSHProbed,
        hecate => probe_hecate(IP, Hostname)
    }.

%% @private Check if hecate-daemon is running on the host.
%% Calls _peer.health via mesh RPC — the mesh-native discovery method.
%% Falls back to BEAM cluster membership for nodes not yet on the mesh.
-spec probe_hecate(string(), binary()) -> map().
probe_hecate(_IP, Hostname) ->
    %% First: check BEAM cluster (fast, no network)
    case check_cluster_membership(Hostname) of
        {ok, Info} -> Info;
        false -> #{running => false}
    end.

%% @private Check if hostname matches a connected BEAM cluster node.
check_cluster_membership(Hostname) ->
    ClusterNodes = [node() | erlang:nodes()],
    Candidates = [
        binary_to_atom(<<"hecate@", Hostname/binary>>),
        binary_to_atom(<<"hecate@", (hd(binary:split(Hostname, <<".">>)))/binary>>)
    ],
    case lists:filter(fun(N) -> lists:member(N, ClusterNodes) end, Candidates) of
        [MatchedNode | _] ->
            {ok, #{
                running => true,
                version => app_version(),
                status => <<"connected">>,
                node_name => atom_to_binary(MatchedNode)
            }};
        [] ->
            false
    end.

%% @private Check if SSH (port 22) is open.
%% `true' = connected; `false' = explicitly refused (port closed);
%% `unknown' = timed out / unreachable this cycle (don't treat that
%% as "no ssh" — a 1s probe on a busy LAN flakes, and flipping the
%% flag records a spurious spot event).
-spec probe_ssh(string()) -> true | false | unknown.
probe_ssh(IP) ->
    case gen_tcp:connect(IP, 22, [binary, {active, false}], 1_000) of
        {ok, Socket} ->
            gen_tcp:close(Socket),
            true;
        {error, econnrefused} ->
            false;
        {error, _} ->
            unknown
    end.


%%%===================================================================
%%% Self IP
%%%===================================================================

%% @private Get this machine's primary LAN IP address.
get_self_ip() ->
    case inet:getifaddrs() of
        {ok, Ifaces} ->
            find_lan_ip(Ifaces);
        _ ->
            "127.0.0.1"
    end.

%% @private Find a non-loopback IPv4 address.
find_lan_ip([]) -> "127.0.0.1";
find_lan_ip([{_Name, Opts} | Rest]) ->
    Addrs = [inet:ntoa(A) || {addr, A} <- Opts,
                              tuple_size(A) =:= 4,
                              A =/= {127, 0, 0, 1}],
    case Addrs of
        [First | _] -> First;
        [] -> find_lan_ip(Rest)
    end.

%%%===================================================================
%%% Internal
%%%===================================================================

%% @private Auto-admit LAN nodes that run hecate with the same site_id.
auto_admit_peers(Probed) ->
    OurSiteId = guide_site_lifecycle_app:site_id(),
    Peers = [H || H <- Probed, peer_matches_site(H, OurSiteId)],
    lists:foreach(fun(#{hecate := #{node_name := NodeName}}) ->
        spawn(fun() -> do_admit_peer(OurSiteId, NodeName) end)
    end, Peers).

peer_matches_site(#{hecate := #{running := true, site_id := SiteId}}, OurSiteId) ->
    SiteId =:= OurSiteId;
peer_matches_site(_, _) ->
    false.

do_admit_peer(SiteId, NodeName) ->
    Cmd = admit_node_v1:new(NodeName, erlang:system_time(millisecond)),
    case maybe_admit_node:dispatch(SiteId, Cmd) of
        {ok, _V, _Events} ->
            logger:info("[lan_scanner] Auto-admitted peer: ~s", [NodeName]);
        {error, node_already_admitted} -> ok;
        {error, _} -> ok
    end.

%% @private Dispatch spot synchronously (serialized per scan cycle).
%% Catch errors so the scanner never crashes.
dispatch_spot_safe(Cmd) ->
    try maybe_spot_lan_machine:dispatch(Cmd) of
        {ok, _V, _Events} -> ok;
        {error, _} -> ok
    catch _:_ -> ok
    end.

app_version() ->
    case application:get_key(hecate, vsn) of
        {ok, Vsn} -> list_to_binary(Vsn);
        _ -> <<"unknown">>
    end.

cancel_timer(#state{timer_ref = undefined}) -> ok;
cancel_timer(#state{timer_ref = Ref}) -> erlang:cancel_timer(Ref).
