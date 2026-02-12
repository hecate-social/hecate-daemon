%%% @doc Tests for resolve_learning_dispute desk
%%% Covers resolve_learning_dispute_v1 command validation and
%%% maybe_resolve_learning_dispute handler business logic.
-module(resolve_learning_dispute_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        learning_id => <<"lrn-test-005">>,
        resolver_id => <<"agent-resolver">>,
        resolution => <<"Original learning is correct">>
    }.

valid_cmd() ->
    {ok, Cmd} = resolve_learning_dispute_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_command_returns_ok_test() ->
    {ok, _Cmd} = resolve_learning_dispute_v1:new(valid_params()).

missing_learning_id_rejected_test() ->
    ?assertEqual({error, missing_required_fields},
                 resolve_learning_dispute_v1:new(#{resolver_id => <<"r1">>})).

resolution_is_optional_test() ->
    Params = #{learning_id => <<"lrn-test-005">>, resolver_id => <<"r1">>},
    {ok, Cmd} = resolve_learning_dispute_v1:new(Params),
    ?assertEqual(undefined, resolve_learning_dispute_v1:get_resolution(Cmd)).

accessors_return_correct_values_test() ->
    {ok, Cmd} = resolve_learning_dispute_v1:new(valid_params()),
    ?assertEqual(<<"lrn-test-005">>, resolve_learning_dispute_v1:get_learning_id(Cmd)),
    ?assertEqual(<<"agent-resolver">>, resolve_learning_dispute_v1:get_resolver_id(Cmd)),
    ?assertEqual(<<"Original learning is correct">>, resolve_learning_dispute_v1:get_resolution(Cmd)).

to_map_has_command_type_test() ->
    {ok, Cmd} = resolve_learning_dispute_v1:new(valid_params()),
    Map = resolve_learning_dispute_v1:to_map(Cmd),
    ?assertEqual(<<"resolve_learning_dispute">>, maps:get(command_type, Map)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_resolve_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_resolve_learning_dispute:handle(Cmd),
    Map = learning_dispute_resolved_v1:to_map(Event),
    ?assertEqual(<<"learning_dispute_resolved_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"lrn-test-005">>, maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-resolver">>, maps:get(resolver_id, Map)),
    ?assertEqual(<<"Original learning is correct">>, maps:get(resolution, Map)).

handle_event_has_resolved_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_resolve_learning_dispute:handle(Cmd),
    ResolvedAt = learning_dispute_resolved_v1:get_resolved_at(Event),
    ?assert(is_integer(ResolvedAt)),
    ?assert(ResolvedAt > 0).

handle_without_resolution_test() ->
    Params = #{learning_id => <<"lrn-test-005">>, resolver_id => <<"r1">>},
    {ok, Cmd} = resolve_learning_dispute_v1:new(Params),
    {ok, [Event]} = maybe_resolve_learning_dispute:handle(Cmd),
    Map = learning_dispute_resolved_v1:to_map(Event),
    ?assertEqual(undefined, maps:get(resolution, Map)).
