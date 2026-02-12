%%% @doc Tests for submit_learning desk
%%% Covers submit_learning_v1 command validation and
%%% maybe_submit_learning handler business logic.
-module(submit_learning_tests).

-include_lib("eunit/include/eunit.hrl").

%%--------------------------------------------------------------------
%% Test helpers
%%--------------------------------------------------------------------

valid_params() ->
    #{
        category => <<"pattern">>,
        domain => <<"erlang">>,
        title => <<"OTP patterns">>,
        submitter_id => <<"agent-1">>
    }.

valid_cmd() ->
    {ok, Cmd} = submit_learning_v1:new(valid_params()),
    Cmd.

%%--------------------------------------------------------------------
%% Command validation tests
%%--------------------------------------------------------------------

valid_submit_returns_ok_test() ->
    {ok, _Cmd} = submit_learning_v1:new(valid_params()).

auto_generated_learning_id_prefix_test() ->
    {ok, Cmd} = submit_learning_v1:new(valid_params()),
    LId = submit_learning_v1:get_learning_id(Cmd),
    ?assert(is_binary(LId)),
    ?assertMatch(<<"lrn-", _/binary>>, LId).

explicit_learning_id_preserved_test() ->
    Params = (valid_params())#{learning_id => <<"lrn-custom-123">>},
    {ok, Cmd} = submit_learning_v1:new(Params),
    ?assertEqual(<<"lrn-custom-123">>, submit_learning_v1:get_learning_id(Cmd)).

invalid_category_rejected_test() ->
    Params = (valid_params())#{category => <<"bogus">>},
    ?assertEqual({error, invalid_category}, submit_learning_v1:new(Params)).

valid_categories_test_() ->
    [fun() ->
        Params = (valid_params())#{category => Cat},
        {ok, _} = submit_learning_v1:new(Params)
     end || Cat <- [<<"pattern">>, <<"antipattern">>, <<"example">>, <<"correction">>]].

invalid_severity_rejected_test() ->
    Params = (valid_params())#{severity => <<"catastrophic">>},
    ?assertEqual({error, invalid_severity}, submit_learning_v1:new(Params)).

valid_severities_test_() ->
    [fun() ->
        Params = (valid_params())#{severity => Sev},
        {ok, _} = submit_learning_v1:new(Params)
     end || Sev <- [<<"critical">>, <<"important">>, <<"suggestion">>]].

invalid_source_rejected_test() ->
    Params = (valid_params())#{source => <<"invented">>},
    ?assertEqual({error, invalid_source}, submit_learning_v1:new(Params)).

valid_sources_test_() ->
    [fun() ->
        Params = (valid_params())#{source => Src},
        {ok, _} = submit_learning_v1:new(Params)
     end || Src <- [<<"discovered">>, <<"taught">>, <<"observed">>]].

confidence_too_high_rejected_test() ->
    Params = (valid_params())#{confidence => 1.5},
    ?assertEqual({error, invalid_confidence}, submit_learning_v1:new(Params)).

confidence_too_low_rejected_test() ->
    Params = (valid_params())#{confidence => -0.1},
    ?assertEqual({error, invalid_confidence}, submit_learning_v1:new(Params)).

confidence_boundary_zero_test() ->
    Params = (valid_params())#{confidence => 0.0},
    {ok, _} = submit_learning_v1:new(Params).

confidence_boundary_one_test() ->
    Params = (valid_params())#{confidence => 1.0},
    {ok, _} = submit_learning_v1:new(Params).

missing_required_fields_test() ->
    ?assertEqual({error, missing_required_fields}, submit_learning_v1:new(#{})).

missing_title_test() ->
    ?assertEqual({error, missing_required_fields},
                 submit_learning_v1:new(#{category => <<"pattern">>, domain => <<"erlang">>})).

defaults_applied_test() ->
    {ok, Cmd} = submit_learning_v1:new(valid_params()),
    ?assertEqual(<<"suggestion">>, submit_learning_v1:get_severity(Cmd)),
    ?assertEqual(0.5, submit_learning_v1:get_confidence(Cmd)),
    ?assertEqual(<<"discovered">>, submit_learning_v1:get_source(Cmd)),
    ?assertEqual([], submit_learning_v1:get_tags(Cmd)),
    ?assertEqual(undefined, submit_learning_v1:get_description(Cmd)).

to_map_roundtrip_test() ->
    {ok, Cmd} = submit_learning_v1:new(valid_params()),
    Map = submit_learning_v1:to_map(Cmd),
    ?assertEqual(<<"submit_learning">>, maps:get(command_type, Map)),
    ?assertEqual(<<"pattern">>, maps:get(category, Map)),
    ?assertEqual(<<"erlang">>, maps:get(domain, Map)),
    ?assertEqual(<<"OTP patterns">>, maps:get(title, Map)),
    ?assertEqual(<<"agent-1">>, maps:get(submitter_id, Map)).

%%--------------------------------------------------------------------
%% Handler tests
%%--------------------------------------------------------------------

handle_valid_submit_returns_event_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_submit_learning:handle(Cmd),
    Map = learning_submitted_v1:to_map(Event),
    ?assertEqual(<<"learning_submitted_v1">>, maps:get(event_type, Map)),
    ?assertEqual(submit_learning_v1:get_learning_id(Cmd), maps:get(learning_id, Map)),
    ?assertEqual(<<"agent-1">>, maps:get(submitter_id, Map)),
    ?assertEqual(<<"pattern">>, maps:get(category, Map)),
    ?assertEqual(<<"erlang">>, maps:get(domain, Map)),
    ?assertEqual(<<"OTP patterns">>, maps:get(title, Map)).

handle_preserves_optional_fields_test() ->
    Params = (valid_params())#{
        description => <<"A description">>,
        bad_example => <<"bad code">>,
        good_example => <<"good code">>,
        context => <<"some context">>,
        tags => [<<"otp">>, <<"gen_server">>]
    },
    {ok, Cmd} = submit_learning_v1:new(Params),
    {ok, [Event]} = maybe_submit_learning:handle(Cmd),
    Map = learning_submitted_v1:to_map(Event),
    ?assertEqual(<<"A description">>, maps:get(description, Map)),
    ?assertEqual(<<"bad code">>, maps:get(bad_example, Map)),
    ?assertEqual(<<"good code">>, maps:get(good_example, Map)),
    ?assertEqual(<<"some context">>, maps:get(context, Map)),
    ?assertEqual([<<"otp">>, <<"gen_server">>], maps:get(tags, Map)).

handle_event_has_submitted_at_test() ->
    Cmd = valid_cmd(),
    {ok, [Event]} = maybe_submit_learning:handle(Cmd),
    SubmittedAt = learning_submitted_v1:get_submitted_at(Event),
    ?assert(is_integer(SubmittedAt)),
    ?assert(SubmittedAt > 0).
