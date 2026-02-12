%%% @doc Tests for unsubscribe_from_mentor desk
%%% Covers unsubscribe_from_mentor_v1 command validation and
%%% maybe_unsubscribe_from_mentor handler business logic.
-module(unsubscribe_from_mentor_tests).

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
    {ok, Cmd} = unsubscribe_from_mentor_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = unsubscribe_from_mentor_v1:new(valid_params()).

missing_mentor_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 unsubscribe_from_mentor_v1:new(#{subscriber_id => <<"s1">>})).

accessors_return_correct_values_test() ->
    {ok, Cmd} = unsubscribe_from_mentor_v1:new(valid_params()),
    ?assertEqual(<<"agent-learner">>, unsubscribe_from_mentor_v1:get_subscriber_id(Cmd)),
    ?assertEqual(<<"agent-mentor-1">>, unsubscribe_from_mentor_v1:get_mentor_id(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = unsubscribe_from_mentor_v1:new(valid_params()),
    Map = unsubscribe_from_mentor_v1:to_map(Cmd),
    ?assertEqual(<<"unsubscribe_from_mentor">>, maps:get(command_type, Map)),
    ?assertEqual(<<"agent-learner">>, maps:get(subscriber_id, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(mentor_id, Map)).

from_map_roundtrip_test() ->
    {ok, Cmd} = unsubscribe_from_mentor_v1:new(valid_params()),
    Map = unsubscribe_from_mentor_v1:to_map(Cmd),
    {ok, Cmd2} = unsubscribe_from_mentor_v1:from_map(Map),
    ?assertEqual(unsubscribe_from_mentor_v1:get_subscriber_id(Cmd),
                 unsubscribe_from_mentor_v1:get_subscriber_id(Cmd2)),
    ?assertEqual(unsubscribe_from_mentor_v1:get_mentor_id(Cmd),
                 unsubscribe_from_mentor_v1:get_mentor_id(Cmd2)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_unsubscribe_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_unsubscribe_from_mentor:handle(Cmd),
    Map = mentor_unsubscribed_v1:to_map(Event),
    ?assertEqual(<<"mentor_unsubscribed_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"agent-learner">>, maps:get(subscriber_id, Map)),
    ?assertEqual(<<"agent-mentor-1">>, maps:get(mentor_id, Map)).

handle_event_has_unsubscribed_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_unsubscribe_from_mentor:handle(Cmd),
    UnsubscribedAt = mentor_unsubscribed_v1:get_unsubscribed_at(Event),
    ?assert(is_integer(UnsubscribedAt)),
    ?assert(UnsubscribedAt > 0).

handle_returns_single_event_test() ->
    Cmd = valid_cmd(),
    {ok, Events} = maybe_unsubscribe_from_mentor:handle(Cmd),
    ?assertEqual(1, length(Events)).
