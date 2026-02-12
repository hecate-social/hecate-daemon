%%% @doc Tests for endorse_learning desk
%%% Covers endorse_learning_v1 command validation and
%%% maybe_endorse_learning handler business logic.
-module(endorse_learning_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        learning_id => <<"lrn-test-003">>,
        agent_id => <<"agent-endorser">>
    }.

valid_cmd() ->
    {ok, Cmd} = endorse_learning_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = endorse_learning_v1:new(valid_params()).

missing_learning_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 endorse_learning_v1:new(#{agent_id => <<"a1">>})).

accessors_return_correct_values_test() ->
    {ok, Cmd} = endorse_learning_v1:new(valid_params()),
    ?assertEqual(<<"lrn-test-003">>, endorse_learning_v1:get_learning_id(Cmd)),
    ?assertEqual(<<"agent-endorser">>, endorse_learning_v1:get_agent_id(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = endorse_learning_v1:new(valid_params()),
    Map = endorse_learning_v1:to_map(Cmd),
    ?assertEqual(<<"endorse_learning">>, maps:get(command_type, Map)),
    ?assertEqual(<<"lrn-test-003">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-endorser">>, maps:get(agent_id, Map)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_endorse_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_endorse_learning:handle(Cmd),
    Map = learning_endorsed_v1:to_map(Event),
    ?assertEqual(<<"learning_endorsed_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"lrn-test-003">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-endorser">>, maps:get(agent_id, Map)).

handle_event_has_endorsed_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_endorse_learning:handle(Cmd),
    EndorsedAt = learning_endorsed_v1:get_endorsed_at(Event),
    ?assert(is_integer(EndorsedAt)),
    ?assert(EndorsedAt > 0).

handle_returns_single_event_test() ->
    Cmd = valid_cmd(),
    {ok, Events} = maybe_endorse_learning:handle(Cmd),
    ?assertEqual(1, length(Events)).
