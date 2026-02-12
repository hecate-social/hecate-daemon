%%% @doc Tests for reject_learning desk
%%% Covers reject_learning_v1 command validation and
%%% maybe_reject_learning handler business logic.
-module(reject_learning_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        learning_id => <<"lrn-test-002">>,
        validator_id => <<"agent-validator">>,
        reason => <<"Inaccurate information">>
    }.

valid_cmd() ->
    {ok, Cmd} = reject_learning_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = reject_learning_v1:new(valid_params()).

missing_learning_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 reject_learning_v1:new(#{validator_id => <<"v1">>})).

reason_is_optional_test() ->
    Params = #{learning_id => <<"lrn-test-002">>, validator_id => <<"v1">>},
    {ok, Cmd} = reject_learning_v1:new(Params),
    ?assertEqual(undefined, reject_learning_v1:get_reason(Cmd)).

accessors_return_correct_values_test() ->
    {ok, Cmd} = reject_learning_v1:new(valid_params()),
    ?assertEqual(<<"lrn-test-002">>, reject_learning_v1:get_learning_id(Cmd)),
    ?assertEqual(<<"agent-validator">>, reject_learning_v1:get_validator_id(Cmd)),
    ?assertEqual(<<"Inaccurate information">>, reject_learning_v1:get_reason(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = reject_learning_v1:new(valid_params()),
    Map = reject_learning_v1:to_map(Cmd),
    ?assertEqual(<<"reject_learning">>, maps:get(command_type, Map)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_reject_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_reject_learning:handle(Cmd),
    Map = learning_rejected_v1:to_map(Event),
    ?assertEqual(<<"learning_rejected_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"lrn-test-002">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-validator">>, maps:get(validator_id, Map)),
    ?assertEqual(<<"Inaccurate information">>, maps:get(reason, Map)).

handle_event_has_rejected_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_reject_learning:handle(Cmd),
    RejectedAt = learning_rejected_v1:get_rejected_at(Event),
    ?assert(is_integer(RejectedAt)),
    ?assert(RejectedAt > 0).

handle_without_reason_test() ->
    Params = #{learning_id => <<"lrn-test-002">>, validator_id => <<"v1">>},
    {ok, Cmd} = reject_learning_v1:new(Params),
    {ok, [Event]} = maybe_reject_learning:handle(Cmd),
    Map = learning_rejected_v1:to_map(Event),
    ?assertEqual(undefined, maps:get(reason, Map)).
