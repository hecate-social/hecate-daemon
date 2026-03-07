%%% @doc Tests for mentor subscription projections (event -> ETS mentor_subscriptions table).
%%%
%%% Creates a named ETS table and calls evoq_projection callbacks directly.
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
    ensure_ets(mentor_subscriptions).

cleanup(_) ->
    catch ets:delete(mentor_subscriptions),
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

proj_subscribed() ->
    Event = #{data => #{
        subscriber_id => <<"agent-001">>,
        mentor_id => <<"mentor-001">>,
        subscribed_at => 1000
    }},
    project(mentor_subscribed_v1_to_subscriptions, Event),
    [{_, S}] = ets:lookup(mentor_subscriptions, {<<"agent-001">>, <<"mentor-001">>}),
    ?assertEqual(<<"agent-001">>, maps:get(subscriber_id, S)),
    ?assertEqual(<<"mentor-001">>, maps:get(mentor_id, S)),
    ?assertEqual(1, maps:get(status, S)),
    ?assertEqual(1000, maps:get(subscribed_at, S)).

proj_unsubscribed() ->
    project(mentor_subscribed_v1_to_subscriptions, #{data => #{
        subscriber_id => <<"agent-001">>,
        mentor_id => <<"mentor-001">>,
        subscribed_at => 1000
    }}),
    project(mentor_unsubscribed_v1_to_subscriptions, #{data => #{
        subscriber_id => <<"agent-001">>,
        mentor_id => <<"mentor-001">>
    }}),
    [{_, S}] = ets:lookup(mentor_subscriptions, {<<"agent-001">>, <<"mentor-001">>}),
    ?assert(maps:get(status, S) band 2 =/= 0).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip() ->
    project(mentor_subscribed_v1_to_subscriptions, #{data => #{
        subscriber_id => <<"agent-rt">>,
        mentor_id => <<"mentor-rt1">>,
        subscribed_at => 1000
    }}),
    project(mentor_subscribed_v1_to_subscriptions, #{data => #{
        subscriber_id => <<"agent-rt">>,
        mentor_id => <<"mentor-rt2">>,
        subscribed_at => 2000
    }}),
    {ok, Results} = get_mentor_subscriptions_page:execute(<<"agent-rt">>),
    ?assertEqual(2, length(Results)),
    Ids = [maps:get(mentor_id, R) || R <- Results],
    ?assert(lists:member(<<"mentor-rt1">>, Ids)),
    ?assert(lists:member(<<"mentor-rt2">>, Ids)).
