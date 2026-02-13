%%% @doc Tests for mentor subscription projections (event -> SQLite mentor_subscriptions table).
%%%
%%% Uses a temp SQLite database via query_mentorships_store.
%%% Each test group gets a fresh database (foreach pattern).
-module(subscriptions_projection_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"mentor_subscribed projects into mentor_subscriptions with status=1",
                fun proj_subscribed/0},
            {"mentor_unsubscribed sets UNSUBSCRIBED bit on status",
                fun proj_unsubscribed/0},
            {"roundtrip: project then get_mentor_subscriptions_page",
                fun roundtrip/0}
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

proj_subscribed() ->
    Event = #{
        subscriber_id => <<"agent-001">>,
        mentor_id => <<"mentor-001">>,
        subscribed_at => 1000
    },
    ok = mentor_subscribed_v1_to_subscriptions:project(Event),
    {ok, Rows} = query_mentorships_store:query(
        "SELECT subscriber_id, mentor_id, status, subscribed_at "
        "FROM mentor_subscriptions", []),
    ?assertEqual(1, length(Rows)),
    [[SubId, MenId, Status, SubAt]] = Rows,
    ?assertEqual(<<"agent-001">>, SubId),
    ?assertEqual(<<"mentor-001">>, MenId),
    ?assertEqual(1, Status),
    ?assertEqual(1000, SubAt).

proj_unsubscribed() ->
    %% First subscribe
    ok = mentor_subscribed_v1_to_subscriptions:project(#{
        subscriber_id => <<"agent-001">>,
        mentor_id => <<"mentor-001">>,
        subscribed_at => 1000
    }),
    %% Then unsubscribe
    ok = mentor_unsubscribed_v1_to_subscriptions:project(#{
        subscriber_id => <<"agent-001">>,
        mentor_id => <<"mentor-001">>
    }),
    {ok, [[Status]]} =
        query_mentorships_store:query(
            "SELECT status FROM mentor_subscriptions "
            "WHERE subscriber_id = ?1 AND mentor_id = ?2",
            [<<"agent-001">>, <<"mentor-001">>]),
    %% SUBSCRIBED=1 | UNSUBSCRIBED=2 = 3
    ?assert(Status band 2 =/= 0).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip() ->
    ok = mentor_subscribed_v1_to_subscriptions:project(#{
        subscriber_id => <<"agent-rt">>,
        mentor_id => <<"mentor-rt1">>,
        subscribed_at => 1000
    }),
    ok = mentor_subscribed_v1_to_subscriptions:project(#{
        subscriber_id => <<"agent-rt">>,
        mentor_id => <<"mentor-rt2">>,
        subscribed_at => 2000
    }),
    {ok, Results} = get_mentor_subscriptions_page:execute(<<"agent-rt">>),
    ?assertEqual(2, length(Results)),
    Ids = [maps:get(mentor_id, R) || R <- Results],
    ?assert(lists:member(<<"mentor-rt1">>, Ids)),
    ?assert(lists:member(<<"mentor-rt2">>, Ids)).
