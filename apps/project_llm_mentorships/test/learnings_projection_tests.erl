%%% @doc Tests for learning projections (event -> ETS learnings table).
%%%
%%% Creates a named ETS table and calls evoq_projection callbacks directly.
-module(learnings_projection_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

projection_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"learning_submitted projects into learnings with status=1",
                fun proj_submitted/0},
            {"learning_validated sets VALIDATED bit and validator_id",
                fun proj_validated/0},
            {"learning_rejected sets REJECTED bit",
                fun proj_rejected/0},
            {"learning_endorsed sets ENDORSED bit and increments endorsement_count",
                fun proj_endorsed/0},
            {"two endorsements increment endorsement_count to 2",
                fun proj_endorsed_twice/0},
            {"learning_disputed sets DISPUTED bit and increments dispute_count",
                fun proj_disputed/0},
            {"learning_dispute_resolved sets RESOLVED bit",
                fun proj_resolved/0},
            {"roundtrip: project then get_learning_by_id",
                fun roundtrip_by_id/0},
            {"roundtrip: project 2 learnings then get_learnings_page",
                fun roundtrip_page/0}
        ]
    }.

%% ===================================================================
%% Setup / Cleanup
%% ===================================================================

setup() ->
    ensure_ets(learnings).

cleanup(_) ->
    catch ets:delete(learnings),
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

submit_event(Id) ->
    #{data => #{
        learning_id => Id,
        submitter_id => <<"agent-001">>,
        category => <<"antipattern">>,
        domain => <<"erlang">>,
        tags => [<<"otp">>, <<"gen_server">>],
        title => <<"Avoid blocking gen_server calls">>,
        description => <<"Long calls block the mailbox">>,
        bad_example => <<"gen_server:call(Pid, heavy_work)">>,
        good_example => <<"gen_server:cast(Pid, {work, self()})">>,
        context => <<"production systems">>,
        severity => <<"warning">>,
        confidence => 0.9,
        source => <<"code_review">>,
        submitted_at => 1000
    }}.

project(Mod, Event) ->
    {ok, _, RM} = Mod:init(#{}),
    {ok, _, _} = Mod:project(Event, #{}, #{}, RM).

project_chain(Steps) ->
    lists:foreach(fun({Mod, Event}) -> project(Mod, Event) end, Steps).

%% ===================================================================
%% Projection tests
%% ===================================================================

proj_submitted() ->
    project(learning_submitted_v1_to_learnings, submit_event(<<"learn-001">>)),
    [{_, L}] = ets:lookup(learnings, <<"learn-001">>),
    ?assertEqual(<<"learn-001">>, maps:get(id, L)),
    ?assertEqual(<<"agent-001">>, maps:get(submitter_id, L)),
    ?assertEqual(<<"antipattern">>, maps:get(category, L)),
    ?assertEqual(<<"erlang">>, maps:get(domain, L)),
    ?assertEqual(<<"Avoid blocking gen_server calls">>, maps:get(title, L)),
    ?assertEqual(1, maps:get(status, L)),
    ?assertEqual(0, maps:get(endorsement_count, L)),
    ?assertEqual(0, maps:get(dispute_count, L)).

proj_validated() ->
    project_chain([
        {learning_submitted_v1_to_learnings, submit_event(<<"learn-002">>)},
        {learning_validated_v1_to_learnings, #{data => #{
            learning_id => <<"learn-002">>,
            validator_id => <<"validator-001">>,
            validated_at => 2000
        }}}
    ]),
    [{_, L}] = ets:lookup(learnings, <<"learn-002">>),
    ?assert(maps:get(status, L) band 2 =/= 0),
    ?assertEqual(<<"validator-001">>, maps:get(validator_id, L)),
    ?assertEqual(2000, maps:get(validated_at, L)).

proj_rejected() ->
    project_chain([
        {learning_submitted_v1_to_learnings, submit_event(<<"learn-003">>)},
        {learning_rejected_v1_to_learnings, #{data => #{
            learning_id => <<"learn-003">>,
            validator_id => <<"validator-002">>
        }}}
    ]),
    [{_, L}] = ets:lookup(learnings, <<"learn-003">>),
    ?assert(maps:get(status, L) band 4 =/= 0),
    ?assertEqual(<<"validator-002">>, maps:get(validator_id, L)).

proj_endorsed() ->
    project_chain([
        {learning_submitted_v1_to_learnings, submit_event(<<"learn-004">>)},
        {learning_validated_v1_to_learnings, #{data => #{
            learning_id => <<"learn-004">>,
            validator_id => <<"validator-001">>,
            validated_at => 2000
        }}},
        {learning_endorsed_v1_to_learnings, #{data => #{
            learning_id => <<"learn-004">>
        }}}
    ]),
    [{_, L}] = ets:lookup(learnings, <<"learn-004">>),
    ?assert(maps:get(status, L) band 8 =/= 0),
    ?assertEqual(1, maps:get(endorsement_count, L)).

proj_endorsed_twice() ->
    project_chain([
        {learning_submitted_v1_to_learnings, submit_event(<<"learn-005">>)},
        {learning_validated_v1_to_learnings, #{data => #{
            learning_id => <<"learn-005">>,
            validator_id => <<"v-001">>,
            validated_at => 2000
        }}},
        {learning_endorsed_v1_to_learnings, #{data => #{learning_id => <<"learn-005">>}}},
        {learning_endorsed_v1_to_learnings, #{data => #{learning_id => <<"learn-005">>}}}
    ]),
    [{_, L}] = ets:lookup(learnings, <<"learn-005">>),
    ?assertEqual(2, maps:get(endorsement_count, L)).

proj_disputed() ->
    project_chain([
        {learning_submitted_v1_to_learnings, submit_event(<<"learn-006">>)},
        {learning_validated_v1_to_learnings, #{data => #{
            learning_id => <<"learn-006">>,
            validator_id => <<"v-001">>,
            validated_at => 2000
        }}},
        {learning_disputed_v1_to_learnings, #{data => #{
            learning_id => <<"learn-006">>
        }}}
    ]),
    [{_, L}] = ets:lookup(learnings, <<"learn-006">>),
    ?assert(maps:get(status, L) band 16 =/= 0),
    ?assertEqual(1, maps:get(dispute_count, L)).

proj_resolved() ->
    project_chain([
        {learning_submitted_v1_to_learnings, submit_event(<<"learn-007">>)},
        {learning_validated_v1_to_learnings, #{data => #{
            learning_id => <<"learn-007">>,
            validator_id => <<"v-001">>,
            validated_at => 2000
        }}},
        {learning_disputed_v1_to_learnings, #{data => #{learning_id => <<"learn-007">>}}},
        {learning_dispute_resolved_v1_to_learnings, #{data => #{learning_id => <<"learn-007">>}}}
    ]),
    [{_, L}] = ets:lookup(learnings, <<"learn-007">>),
    ?assert(maps:get(status, L) band 32 =/= 0).

%% ===================================================================
%% Roundtrip tests: project -> query via query desk modules
%% ===================================================================

roundtrip_by_id() ->
    project(learning_submitted_v1_to_learnings, submit_event(<<"learn-rt1">>)),
    {ok, Map} = get_learning_by_id:execute(<<"learn-rt1">>),
    ?assertEqual(<<"learn-rt1">>, maps:get(id, Map)),
    ?assertEqual(<<"agent-001">>, maps:get(submitter_id, Map)),
    ?assertEqual(<<"antipattern">>, maps:get(category, Map)),
    ?assertEqual(<<"erlang">>, maps:get(domain, Map)),
    ?assertEqual(<<"Avoid blocking gen_server calls">>, maps:get(title, Map)),
    ?assertEqual(1, maps:get(status, Map)),
    ?assertEqual(0, maps:get(endorsement_count, Map)),
    ?assertEqual(0, maps:get(dispute_count, Map)),
    ?assertEqual([<<"otp">>, <<"gen_server">>], maps:get(tags, Map)).

roundtrip_page() ->
    project(learning_submitted_v1_to_learnings, submit_event(<<"learn-pg1">>)),
    Event2 = #{data => #{
        learning_id => <<"learn-pg2">>,
        submitter_id => <<"agent-002">>,
        category => <<"antipattern">>,
        domain => <<"erlang">>,
        title => <<"Second learning">>,
        submitted_at => 2000
    }},
    project(learning_submitted_v1_to_learnings, Event2),
    {ok, Results} = get_learnings_page:execute(#{limit => 50, offset => 0}),
    ?assertEqual(2, length(Results)),
    %% Ordered by submitted_at DESC, so learn-pg2 first
    [First | _] = Results,
    ?assertEqual(<<"learn-pg2">>, maps:get(id, First)).
