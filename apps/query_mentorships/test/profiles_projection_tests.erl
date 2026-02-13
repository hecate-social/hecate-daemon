%%% @doc Tests for mentor profile projections (event -> SQLite mentor_profiles table).
%%%
%%% Uses a temp SQLite database via query_mentorships_store.
%%% Each test group gets a fresh database (foreach pattern).
-module(profiles_projection_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"expertise_declared projects into mentor_profiles with status=1",
                fun proj_declared/0},
            {"expertise_withdrawn sets WITHDRAWN bit on status",
                fun proj_withdrawn/0},
            {"roundtrip: project then get_mentor_profile_by_id",
                fun roundtrip_by_id/0},
            {"roundtrip: project then get_mentors_page",
                fun roundtrip_page/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    ok = filelib:ensure_dir("data/dummy"),
    file:delete("data/query_mentorships.db"),
    file:delete("data/query_mentorships.db-wal"),
    file:delete("data/query_mentorships.db-shm"),
    {ok, _} = application:ensure_all_started(esqlite),
    {ok, Pid} = query_mentorships_store:start_link(),
    query_mentorships_store:init_schema(),
    Pid.

cleanup(Pid) ->
    gen_server:stop(Pid),
    file:delete("data/query_mentorships.db"),
    file:delete("data/query_mentorships.db-wal"),
    file:delete("data/query_mentorships.db-shm"),
    ok.

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_declared() ->
    Event = #{
        agent_id => <<"agent-001">>,
        domains => [<<"erlang">>, <<"elixir">>],
        declared_at => 1000
    },
    ok = expertise_declared_v1_to_profiles:project(Event),
    {ok, Rows} = query_mentorships_store:query(
        "SELECT agent_id, domains, status, declared_at "
        "FROM mentor_profiles", []),
    ?assertEqual(1, length(Rows)),
    [[AgentId, DomainsJson, Status, DeclaredAt]] = Rows,
    ?assertEqual(<<"agent-001">>, AgentId),
    ?assertEqual(1, Status),
    ?assertEqual(1000, DeclaredAt),
    DecodedDomains = json:decode(DomainsJson),
    ?assertEqual([<<"erlang">>, <<"elixir">>], DecodedDomains).

proj_withdrawn() ->
    %% First declare
    ok = expertise_declared_v1_to_profiles:project(#{
        agent_id => <<"agent-001">>,
        domains => [<<"erlang">>],
        declared_at => 1000
    }),
    %% Then withdraw
    ok = expertise_withdrawn_v1_to_profiles:project(#{
        agent_id => <<"agent-001">>
    }),
    {ok, [[Status]]} =
        query_mentorships_store:query(
            "SELECT status FROM mentor_profiles WHERE agent_id = ?1",
            [<<"agent-001">>]),
    %% DECLARED=1 | WITHDRAWN=2 = 3
    ?assert(Status band 2 =/= 0).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip_by_id() ->
    ok = expertise_declared_v1_to_profiles:project(#{
        agent_id => <<"agent-rt1">>,
        domains => [<<"erlang">>, <<"otp">>],
        declared_at => 1000
    }),
    {ok, Map} = get_mentor_profile_by_id:execute(<<"agent-rt1">>),
    ?assertEqual(<<"agent-rt1">>, maps:get(agent_id, Map)),
    ?assertEqual([<<"erlang">>, <<"otp">>], maps:get(domains, Map)),
    ?assertEqual(1, maps:get(status, Map)),
    ?assertEqual(1000, maps:get(declared_at, Map)).

roundtrip_page() ->
    ok = expertise_declared_v1_to_profiles:project(#{
        agent_id => <<"agent-pg1">>,
        domains => [<<"erlang">>],
        declared_at => 1000
    }),
    ok = expertise_declared_v1_to_profiles:project(#{
        agent_id => <<"agent-pg2">>,
        domains => [<<"elixir">>],
        declared_at => 2000
    }),
    {ok, Results} = get_mentors_page:execute(),
    ?assertEqual(2, length(Results)),
    Ids = [maps:get(agent_id, R) || R <- Results],
    ?assert(lists:member(<<"agent-pg1">>, Ids)),
    ?assert(lists:member(<<"agent-pg2">>, Ids)).
