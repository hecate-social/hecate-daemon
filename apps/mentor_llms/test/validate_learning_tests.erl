%%% @doc Tests for validate_learning desk
%%% Covers validate_learning_v1 command validation and
%%% maybe_validate_learning handler business logic.
-module(validate_learning_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        learning_id => <<"lrn-test-001">>,
        validator_id => <<"agent-validator">>
    }.

valid_cmd() ->
    {ok, Cmd} = validate_learning_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = validate_learning_v1:new(valid_params()).

missing_learning_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 validate_learning_v1:new(#{validator_id => <<"v1">>})).

accessors_return_correct_values_test() ->
    {ok, Cmd} = validate_learning_v1:new(valid_params()),
    ?assertEqual(<<"lrn-test-001">>, validate_learning_v1:get_learning_id(Cmd)),
    ?assertEqual(<<"agent-validator">>, validate_learning_v1:get_validator_id(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = validate_learning_v1:new(valid_params()),
    Map = validate_learning_v1:to_map(Cmd),
    ?assertEqual(<<"validate_learning">>, maps:get(command_type, Map)),
    ?assertEqual(<<"lrn-test-001">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-validator">>, maps:get(validator_id, Map)).

from_map_roundtrip_test() ->
    {ok, Cmd} = validate_learning_v1:new(valid_params()),
    Map = validate_learning_v1:to_map(Cmd),
    {ok, Cmd2} = validate_learning_v1:from_map(Map),
    ?assertEqual(validate_learning_v1:get_learning_id(Cmd),
                 validate_learning_v1:get_learning_id(Cmd2)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_validate_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_validate_learning:handle(Cmd),
    Map = learning_validated_v1:to_map(Event),
    ?assertEqual(<<"learning_validated_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"lrn-test-001">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-validator">>, maps:get(validator_id, Map)).

handle_event_has_validated_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_validate_learning:handle(Cmd),
    ValidatedAt = learning_validated_v1:get_validated_at(Event),
    ?assert(is_integer(ValidatedAt)),
    ?assert(ValidatedAt > 0).

handle_returns_single_event_test() ->
    Cmd = valid_cmd(),
    {ok, Events} = maybe_validate_learning:handle(Cmd),
    ?assertEqual(1, length(Events)).
