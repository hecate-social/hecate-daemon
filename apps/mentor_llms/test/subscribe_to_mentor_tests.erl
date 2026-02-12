%%% @doc Tests for subscribe_to_mentor desk
%%% Covers subscribe_to_mentor_v1 command validation and
%%% maybe_subscribe_to_mentor handler business logic.
-module(subscribe_to_mentor_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        subscriber_id => <<"agent-learner">>,
        mentor_id => <<"agent-mentor-1">>
    }.

valid_cmd() ->
    {ok, Cmd} = subscribe_to_mentor_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = subscribe_to_mentor_v1:new(valid_params()).

missing_mentor_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 subscribe_to_mentor_v1:new(#{subscriber_id => <<"s1">>})).

accessors_return_correct_values_test() ->
    {ok, Cmd} = subscribe_to_mentor_v1:new(valid_params()),
    ?assertEqual(<<"agent-learner">>, subscribe_to_mentor_v1:get_subscriber_id(Cmd)),
    ?assertEqual(<<"agent-mentor-1">>, subscribe_to_mentor_v1:get_mentor_id(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = subscribe_to_mentor_v1:new(valid_params()),
    Map = subscribe_to_mentor_v1:to_map(Cmd),
    ?assertEqual(<<"subscribe_to_mentor">>, maps:get(command_type, Map)),
    ?assertEqual(<<"agent-learner">>, maps:get(subscriber_id, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(mentor_id, Map)).

from_map_roundtrip_test() ->
    {ok, Cmd} = subscribe_to_mentor_v1:new(valid_params()),
    Map = subscribe_to_mentor_v1:to_map(Cmd),
    {ok, Cmd2} = subscribe_to_mentor_v1:from_map(Map),
    ?assertEqual(subscribe_to_mentor_v1:get_subscriber_id(Cmd),
                 subscribe_to_mentor_v1:get_subscriber_id(Cmd2)),
    ?assertEqual(subscribe_to_mentor_v1:get_mentor_id(Cmd),
                 subscribe_to_mentor_v1:get_mentor_id(Cmd2)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_subscribe_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_subscribe_to_mentor:handle(Cmd),
    Map = mentor_subscribed_v1:to_map(Event),
    ?assertEqual(<<"mentor_subscribed_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"agent-learner">>, maps:get(subscriber_id, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(mentor_id, Map)).

handle_event_has_subscribed_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_subscribe_to_mentor:handle(Cmd),
    SubscribedAt = mentor_subscribed_v1:get_subscribed_at(Event),
    ?assert(is_integer(SubscribedAt)),
    ?assert(SubscribedAt > 0).

handle_returns_single_event_test() ->
    Cmd = valid_cmd(),
    {ok, Events} = maybe_subscribe_to_mentor:handle(Cmd),
    ?assertEqual(1, length(Events)).
