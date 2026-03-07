%%% @doc Tests for mentor profile projections (event -> ETS mentor_profiles table).
%%%
%%% Creates a named ETS table and calls evoq_projection callbacks directly.
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
    ensure_ets(mentor_profiles).

cleanup(_) ->
    catch ets:delete(mentor_profiles),
    ok.

ensure_ets(Name) ->
    case ets:whereis(Name) of
        undefined ->
            ets:new(Name, [public, named_table, set, {read_concurrency, true}]);
        _ ->
            ets:delete_all_objects(Name),
            Name
    end.

%% ===================================================================
%% Helpers
%% ===================================================================

project(Mod, Event) ->
    {ok, _, RM} = Mod:init(#{}),
    {ok, _, _} = Mod:project(Event, #{}, #{}, RM).

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_declared() ->
    Event = #{data => #{
        agent_id => <<"agent-001">>,
        domains => [<<"erlang">>, <<"elixir">>],
        declared_at => 1000
    }},
    project(expertise_declared_v1_to_profiles, Event),
    [{_, P}] = ets:lookup(mentor_profiles, <<"agent-001">>),
    ?assertEqual(<<"agent-001">>, maps:get(agent_id, P)),
    ?assertEqual(1, maps:get(status, P)),
    ?assertEqual(1000, maps:get(declared_at, P)),
    ?assertEqual([<<"erlang">>, <<"elixir">>], maps:get(domains, P)).

proj_withdrawn() ->
    project(expertise_declared_v1_to_profiles, #{data => #{
        agent_id => <<"agent-001">>,
        domains => [<<"erlang">>],
        declared_at => 1000
    }}),
    project(expertise_withdrawn_v1_to_profiles, #{data => #{
        agent_id => <<"agent-001">>
    }}),
    [{_, P}] = ets:lookup(mentor_profiles, <<"agent-001">>),
    ?assert(maps:get(status, P) band 2 =/= 0).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip_by_id() ->
    project(expertise_declared_v1_to_profiles, #{data => #{
        agent_id => <<"agent-rt1">>,
        domains => [<<"erlang">>, <<"otp">>],
        declared_at => 1000
    }}),
    {ok, Map} = get_mentor_profile_by_id:execute(<<"agent-rt1">>),
    ?assertEqual(<<"agent-rt1">>, maps:get(agent_id, Map)),
    ?assertEqual([<<"erlang">>, <<"otp">>], maps:get(domains, Map)),
    ?assertEqual(1, maps:get(status, Map)),
    ?assertEqual(1000, maps:get(declared_at, Map)).

roundtrip_page() ->
    project(expertise_declared_v1_to_profiles, #{data => #{
        agent_id => <<"agent-pg1">>,
        domains => [<<"erlang">>],
        declared_at => 1000
    }}),
    project(expertise_declared_v1_to_profiles, #{data => #{
        agent_id => <<"agent-pg2">>,
        domains => [<<"elixir">>],
        declared_at => 2000
    }}),
    {ok, Results} = get_mentors_page:execute(),
    ?assertEqual(2, length(Results)),
    Ids = [maps:get(agent_id, R) || R <- Results],
    ?assert(lists:member(<<"agent-pg1">>, Ids)),
    ?assert(lists:member(<<"agent-pg2">>, Ids)).
