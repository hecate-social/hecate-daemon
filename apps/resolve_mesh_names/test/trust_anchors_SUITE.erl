%%% @doc CT suite for the trust_anchors desk. PLAN PART1 §5.6.
%%%
%%% Coverage:
%%%   - get/1 returns no_trust_root on empty registry
%%%   - put then get round-trip
%%%   - put twice replaces (operator-led rotation)
%%%   - list returns all entries
%%%   - remove deletes; get returns no_trust_root after
%%%   - bootstrap from app env compiled_in_seeds at init
%%%   - put rejects malformed pubkeys (wrong length, wrong type)
%%% @end
-module(trust_anchors_SUITE).
-include_lib("common_test/include/ct.hrl").

-export([all/0, init_per_suite/1, end_per_suite/1,
         init_per_testcase/2, end_per_testcase/2]).
-export([
    get_returns_no_trust_root_when_empty/1,
    put_then_get_roundtrip/1,
    put_twice_replaces/1,
    put_rejects_short_pubkey/1,
    put_rejects_non_binary_pubkey/1,
    put_rejects_non_binary_realm/1,
    list_returns_all/1,
    remove_deletes_entry/1,
    count_tracks_size/1,
    bootstrap_loads_compiled_in_seeds/1,
    bootstrap_skips_malformed_seeds/1
]).

all() ->
    [
        get_returns_no_trust_root_when_empty,
        put_then_get_roundtrip,
        put_twice_replaces,
        put_rejects_short_pubkey,
        put_rejects_non_binary_pubkey,
        put_rejects_non_binary_realm,
        list_returns_all,
        remove_deletes_entry,
        count_tracks_size,
        bootstrap_loads_compiled_in_seeds,
        bootstrap_skips_malformed_seeds
    ].

%% Per-testcase fresh start so tests don't leak state into each other.
init_per_suite(Config) -> Config.
end_per_suite(_Config) -> ok.

init_per_testcase(TC, Config) ->
    %% Configure compiled-in seeds for the bootstrap-specific cases;
    %% start with a clean app env for every other case.
    case TC of
        bootstrap_loads_compiled_in_seeds ->
            application:set_env(resolve_mesh_names, compiled_in_seeds,
                                [{<<"io.bootstrap.test">>, key(1)},
                                 {<<"io.another.test">>, key(2)}]);
        bootstrap_skips_malformed_seeds ->
            application:set_env(resolve_mesh_names, compiled_in_seeds,
                                [{<<"io.good.test">>, key(3)},
                                 {<<"io.bad.shortkey">>, <<"too_short">>},
                                 {<<"io.bad.nonbin">>, not_a_binary}]);
        _ ->
            application:set_env(resolve_mesh_names, compiled_in_seeds, [])
    end,
    {ok, Pid} = trust_anchors:start_link(),
    unlink(Pid),
    [{anchors_pid, Pid} | Config].

end_per_testcase(_TC, Config) ->
    case ?config(anchors_pid, Config) of
        undefined -> ok;
        Pid when is_pid(Pid) ->
            case is_process_alive(Pid) of
                true  -> exit(Pid, shutdown), wait_dead(Pid, 100);
                false -> ok
            end
    end,
    application:unset_env(resolve_mesh_names, compiled_in_seeds),
    ok.

wait_dead(_Pid, 0) -> ok;
wait_dead(Pid, N) ->
    case is_process_alive(Pid) of
        false -> ok;
        true  -> timer:sleep(10), wait_dead(Pid, N - 1)
    end.

%% Generate a deterministic 32-byte fake pubkey for testing.
key(N) when is_integer(N) ->
    Tag = list_to_binary(io_lib:format("pk_~p", [N])),
    Pad = binary:copy(<<N>>, 32 - byte_size(Tag)),
    <<Tag/binary, Pad/binary>>.

%%====================================================================
%% Empty registry
%%====================================================================

get_returns_no_trust_root_when_empty(_Config) ->
    {error, no_trust_root} = trust_anchors:get(<<"io.macula">>),
    [] = trust_anchors:list(),
    0  = trust_anchors:count(),
    ok.

%%====================================================================
%% put/get
%%====================================================================

put_then_get_roundtrip(_Config) ->
    Pk = key(10),
    ok = trust_anchors:put(<<"io.macula">>, Pk),
    {ok, Pk} = trust_anchors:get(<<"io.macula">>),
    1 = trust_anchors:count(),
    ok.

put_twice_replaces(_Config) ->
    Pk1 = key(20),
    Pk2 = key(21),
    ok = trust_anchors:put(<<"io.realm">>, Pk1),
    {ok, Pk1} = trust_anchors:get(<<"io.realm">>),
    %% Operator-led rotation: same realm, new pubkey.
    ok = trust_anchors:put(<<"io.realm">>, Pk2),
    {ok, Pk2} = trust_anchors:get(<<"io.realm">>),
    1 = trust_anchors:count(),
    ok.

%%====================================================================
%% put validation
%%====================================================================

put_rejects_short_pubkey(_Config) ->
    {error, invalid_seed} = trust_anchors:put(<<"io.x">>, <<"too_short">>),
    {error, no_trust_root} = trust_anchors:get(<<"io.x">>),
    ok.

put_rejects_non_binary_pubkey(_Config) ->
    {error, invalid_seed} = trust_anchors:put(<<"io.x">>, not_a_binary),
    ok.

put_rejects_non_binary_realm(_Config) ->
    {error, invalid_seed} = trust_anchors:put(not_a_binary, key(30)),
    ok.

%%====================================================================
%% list/count/remove
%%====================================================================

list_returns_all(_Config) ->
    Pk1 = key(40),
    Pk2 = key(41),
    Pk3 = key(42),
    ok = trust_anchors:put(<<"io.a">>, Pk1),
    ok = trust_anchors:put(<<"io.b">>, Pk2),
    ok = trust_anchors:put(<<"io.c">>, Pk3),
    L = trust_anchors:list(),
    3 = length(L),
    %% Order is ETS-implementation-defined; sort by realm to compare.
    Sorted = lists:keysort(1, L),
    [{<<"io.a">>, Pk1}, {<<"io.b">>, Pk2}, {<<"io.c">>, Pk3}] = Sorted,
    ok.

remove_deletes_entry(_Config) ->
    Pk = key(50),
    ok = trust_anchors:put(<<"io.gone">>, Pk),
    {ok, Pk} = trust_anchors:get(<<"io.gone">>),
    ok = trust_anchors:remove(<<"io.gone">>),
    {error, no_trust_root} = trust_anchors:get(<<"io.gone">>),
    0 = trust_anchors:count(),
    ok.

count_tracks_size(_Config) ->
    0 = trust_anchors:count(),
    ok = trust_anchors:put(<<"io.a">>, key(60)),
    1 = trust_anchors:count(),
    ok = trust_anchors:put(<<"io.b">>, key(61)),
    2 = trust_anchors:count(),
    ok = trust_anchors:remove(<<"io.a">>),
    1 = trust_anchors:count(),
    ok.

%%====================================================================
%% Bootstrap from app env
%%====================================================================

bootstrap_loads_compiled_in_seeds(_Config) ->
    %% init_per_testcase set the env + started the gen_server
    %% before this test ran, so the seeds should already be loaded.
    {ok, _} = trust_anchors:get(<<"io.bootstrap.test">>),
    {ok, _} = trust_anchors:get(<<"io.another.test">>),
    2 = trust_anchors:count(),
    ok.

bootstrap_skips_malformed_seeds(_Config) ->
    %% The good seed is loaded; the two bad seeds are silently
    %% skipped (with a logger:warning/2 in the actual code).
    {ok, _} = trust_anchors:get(<<"io.good.test">>),
    {error, no_trust_root} = trust_anchors:get(<<"io.bad.shortkey">>),
    {error, no_trust_root} = trust_anchors:get(<<"io.bad.nonbin">>),
    1 = trust_anchors:count(),
    ok.
