%%% @doc Tests for dispute_learning desk
%%% Covers dispute_learning_v1 command validation and
%%% maybe_dispute_learning handler business logic.
-module(dispute_learning_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        learning_id => <<"lrn-test-004">>,
        agent_id => <<"agent-disputer">>,
        reason => <<"Contradicts established patterns">>
    }.

valid_cmd() ->
    {ok, Cmd} = dispute_learning_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = dispute_learning_v1:new(valid_params()).

missing_learning_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 dispute_learning_v1:new(#{agent_id => <<"a1">>})).

reason_is_optional_test() ->
    Params = #{learning_id => <<"lrn-test-004">>, agent_id => <<"a1">>},
    {ok, Cmd} = dispute_learning_v1:new(Params),
    ?assertEqual(undefined, dispute_learning_v1:get_reason(Cmd)).

accessors_return_correct_values_test() ->
    {ok, Cmd} = dispute_learning_v1:new(valid_params()),
    ?assertEqual(<<"lrn-test-004">>, dispute_learning_v1:get_learning_id(Cmd)),
    ?assertEqual(<<"agent-disputer">>, dispute_learning_v1:get_agent_id(Cmd)),
    ?assertEqual(<<"Contradicts established patterns">>, dispute_learning_v1:get_reason(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = dispute_learning_v1:new(valid_params()),
    Map = dispute_learning_v1:to_map(Cmd),
    ?assertEqual(<<"dispute_learning">>, maps:get(command_type, Map)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_dispute_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_dispute_learning:handle(Cmd),
    Map = learning_disputed_v1:to_map(Event),
    ?assertEqual(<<"learning_disputed_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"lrn-test-004">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-disputer">>, maps:get(agent_id, Map)),
    ?assertEqual(<<"Contradicts established patterns">>, maps:get(reason, Map)).

handle_event_has_disputed_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_dispute_learning:handle(Cmd),
    DisputedAt = learning_disputed_v1:get_disputed_at(Event),
    ?assert(is_integer(DisputedAt)),
    ?assert(DisputedAt > 0).

handle_without_reason_test() ->
    Params = #{learning_id => <<"lrn-test-004">>, agent_id => <<"a1">>},
    {ok, Cmd} = dispute_learning_v1:new(Params),
    {ok, [Event]} = maybe_dispute_learning:handle(Cmd),
    Map = learning_disputed_v1:to_map(Event),
    ?assertEqual(undefined, maps:get(reason, Map)).
