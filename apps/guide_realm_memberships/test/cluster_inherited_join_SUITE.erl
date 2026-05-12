%%% @doc CT suite for the boot_daemon site pg relay seam.
%%%
%%% Validates that a message published via `boot_daemon:broadcast_to_site/2`
%%% on one daemon reaches another daemon in the site that has joined
%%% the `{boot_daemon, site_realm_memberships}` pg group.
%%%
%%% Intentionally narrower than the full realm-join flow — testing the
%%% actual `initiate_realm_membership` / `confirm_realm_membership`
%%% dispatch requires the entire reckon-db + evoq + domain stack which
%%% is prohibitively heavy to bring up in CT. The seam mechanics are
%%% the layer that actually needed the 2026-04-24 boot_daemon carve-out
%%% and are the regression risk worth guarding.
%%%
%%% Run:
%%%   rebar3 ct --suite apps/guide_realm_memberships/test/cluster_inherited_join_SUITE
%%% @end
-module(cluster_inherited_join_SUITE).

-include_lib("common_test/include/ct.hrl").
-include_lib("stdlib/include/assert.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([broadcast_reaches_site_daemon/1,
         broadcast_skips_self/1,
         site_daemon_without_group_is_ignored/1]).
-export([collector_loop/1, pg_keepalive/0]).

-define(GROUP, {boot_daemon, site_realm_memberships}).
-define(COOKIE, inherit_join_test_cookie).

all() ->
    [broadcast_reaches_site_daemon,
     broadcast_skips_self,
     site_daemon_without_group_is_ignored].

init_per_suite(Config) ->
    %% Make sure this runner node has a long name and a known cookie so
    %% spawned daemons can connect back.
    case net_kernel:get_state() of
        #{started := no} ->
            {ok, _} = net_kernel:start(ct_main, #{name_domain => shortnames});
        _ ->
            ok
    end,
    erlang:set_cookie(node(), ?COOKIE),
    Config.

end_per_suite(_Config) ->
    ok.

init_per_testcase(_TC, Config) ->
    {ok, PidA, NodeA} = start_daemon(a),
    {ok, PidB, NodeB} = start_daemon(b),
    load_test_code([NodeA, NodeB]),
    start_pg([NodeA, NodeB]),
    [{daemon_a, {PidA, NodeA}},
     {daemon_b, {PidB, NodeB}} | Config].

end_per_testcase(_TC, Config) ->
    {PidA, _} = ?config(daemon_a, Config),
    {PidB, _} = ?config(daemon_b, Config),
    catch peer:stop(PidA),
    catch peer:stop(PidB),
    ok.

%%====================================================================
%% Cases
%%====================================================================

%% Daemon B joins the pg group via a collector process; daemon A
%% publishes via boot_daemon:broadcast_to_site; B's collector receives
%% the {site_realm_event, ...} message.
broadcast_reaches_site_daemon(Config) ->
    {_, NodeA} = ?config(daemon_a, Config),
    {_, NodeB} = ?config(daemon_b, Config),

    Self = self(),
    CollectorB = erpc:call(NodeB, erlang, spawn,
                           [?MODULE, collector_loop, [Self]]),
    ok = erpc:call(NodeB, pg, join, [?GROUP, CollectorB]),
    ok = wait_until_members_visible(NodeA, 1, 2000),

    EventType = <<"realm_membership_initiated_v1">>,
    Payload = #{membership_id => <<"test-mid">>,
                realm_url => <<"https://io.macula:4433">>,
                initiated_at => 1700000000000},
    ok = erpc:call(NodeA, boot_daemon, broadcast_to_site, [EventType, Payload]),

    Received = recv_site_event(1000),
    ?assertMatch({site_realm_event, EventType, Payload, NodeA}, Received).

%% Broadcast MUST skip the publishing daemon itself — the local event
%% store already produced this event; re-dispatching it would create a
%% subscription loop (relay PM -> self listener -> relay PM ...).
broadcast_skips_self(Config) ->
    {_, NodeA} = ?config(daemon_a, Config),

    Self = self(),
    CollectorA = erpc:call(NodeA, erlang, spawn,
                           [?MODULE, collector_loop, [Self]]),
    ok = erpc:call(NodeA, pg, join, [?GROUP, CollectorA]),

    EventType = <<"realm_membership_confirmed_v1">>,
    Payload = #{membership_id => <<"mid-2">>, realm_id => <<"io.macula">>},
    ok = erpc:call(NodeA, boot_daemon, broadcast_to_site, [EventType, Payload]),

    ?assertEqual(timeout, recv_site_event(300)).

%% A site daemon that hasn't joined the pg group does not receive
%% anything — broadcast fans out to pg members only.
site_daemon_without_group_is_ignored(Config) ->
    {_, NodeA} = ?config(daemon_a, Config),
    {_, NodeB} = ?config(daemon_b, Config),

    Self = self(),
    CollectorB = erpc:call(NodeB, erlang, spawn,
                           [?MODULE, collector_loop, [Self]]),
    %% Intentionally do NOT join the pg group.
    _ = CollectorB,

    EventType = <<"realm_membership_initiated_v1">>,
    ok = erpc:call(NodeA, boot_daemon, broadcast_to_site, [EventType, #{}]),

    ?assertEqual(timeout, recv_site_event(300)).

%%====================================================================
%% Helpers
%%====================================================================

start_daemon(Tag) ->
    Name = list_to_atom("inherit_join_" ++ atom_to_list(Tag)),
    {ok, Pid, NodeName} = peer:start_link(#{name => Name,
                                            host => "127.0.0.1",
                                            connection => standard_io,
                                            args => ["-setcookie", atom_to_list(?COOKIE)]}),
    true = erlang:set_cookie(NodeName, ?COOKIE),
    pong = net_adm:ping(NodeName),
    {ok, Pid, NodeName}.

%% Add the compiled boot_daemon ebin AND this test suite's ebin to
%% each daemon's code path so `boot_daemon:broadcast_to_site/2` and
%% `?MODULE:collector_loop/1` resolve remotely.
load_test_code(Nodes) ->
    %% This module's beam file directory — test suites are compiled
    %% into the umbrella app's test ebin under rebar3.
    SuiteEbin = filename:dirname(code:which(?MODULE)),
    EbinDirs = [filename:join(code:lib_dir(boot_daemon), "ebin"),
                SuiteEbin],
    lists:foreach(fun(N) ->
        lists:foreach(
            fun(Ebin) -> true = erpc:call(N, code, add_path, [Ebin]) end,
            EbinDirs),
        {module, boot_daemon} = erpc:call(N, code, load_file, [boot_daemon]),
        {module, ?MODULE}     = erpc:call(N, code, load_file, [?MODULE])
    end, Nodes).

%% Start `pg` inside a long-lived keepalive process on each daemon — the
%% pg scope is linked to its starter, so running it inside an ephemeral
%% erpc worker would let it die as soon as the RPC reply returns.
start_pg(Nodes) ->
    lists:foreach(fun(N) ->
        _ = erpc:call(N, erlang, spawn, [?MODULE, pg_keepalive, []]),
        ok = wait_until_pg_registered(N, 1000)
    end, Nodes).

wait_until_pg_registered(Node, TimeoutMs) ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    wait_pg_loop(Node, Deadline).

wait_pg_loop(Node, Deadline) ->
    case erpc:call(Node, erlang, whereis, [pg]) of
        undefined ->
            case erlang:monotonic_time(millisecond) >= Deadline of
                true  -> {error, pg_not_registered};
                false ->
                    timer:sleep(25),
                    wait_pg_loop(Node, Deadline)
            end;
        Pid when is_pid(Pid) ->
            ok
    end.

pg_keepalive() ->
    case pg:start_link() of
        {ok, _}                        -> ok;
        {error, {already_started, _}} -> ok
    end,
    receive stop -> ok end.

collector_loop(Parent) ->
    receive
        {site_realm_event, _, _, _} = Msg ->
            Parent ! Msg,
            collector_loop(Parent);
        stop ->
            ok;
        Other ->
            Parent ! {unexpected, Other},
            collector_loop(Parent)
    end.

recv_site_event(Timeout) ->
    receive
        {site_realm_event, _, _, _} = Msg -> Msg
    after Timeout -> timeout
    end.

%% pg membership is eventually consistent across nodes — poll until the
%% publishing daemon sees the expected member count or the deadline fires.
wait_until_members_visible(Node, Expected, TimeoutMs) ->
    Deadline = erlang:monotonic_time(millisecond) + TimeoutMs,
    wait_members_loop(Node, Expected, Deadline).

wait_members_loop(Node, Expected, Deadline) ->
    Members = erpc:call(Node, pg, get_members, [?GROUP]),
    case length(Members) >= Expected of
        true -> ok;
        false ->
            case erlang:monotonic_time(millisecond) >= Deadline of
                true -> {error, {timeout_waiting_for_members, Expected, length(Members)}};
                false ->
                    timer:sleep(50),
                    wait_members_loop(Node, Expected, Deadline)
            end
    end.
