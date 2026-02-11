%%% @doc Layer 2b+2c: Handler + Aggregate execute/2 tests.
%%% Tests handle/1 business logic and execute/2 state machine guards.
%%% No I/O — builds state via apply_event chains, then tests commands.
-module(setup_venture_handler_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("setup_venture/include/venture_status.hrl").

%% ===================================================================
%% Helpers: build state from event sequence
%% ===================================================================

fresh_state() ->
    setup_aggregate:initial_state().

setup_state() ->
    S = fresh_state(),
    setup_aggregate:apply_event(setup_event_map(), S).

refined_state() ->
    setup_aggregate:apply_event(refine_event_map(), setup_state()).

submitted_state() ->
    setup_aggregate:apply_event(submit_event_map(), setup_state()).

archived_state() ->
    setup_aggregate:apply_event(archive_event_map(), setup_state()).

setup_event_map() ->
    #{<<"event_type">> => <<"venture_setup_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"name">> => <<"Test">>,
      <<"brief">> => <<"A test">>,
      <<"initiated_at">> => 1000,
      <<"initiated_by">> => <<"test@host">>}.

refine_event_map() ->
    #{<<"event_type">> => <<"venture_vision_refined_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"brief">> => <<"Refined">>,
      <<"refined_at">> => 2000}.

submit_event_map() ->
    #{<<"event_type">> => <<"venture_vision_submitted_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"submitted_at">> => 3000}.

archive_event_map() ->
    #{<<"event_type">> => <<"venture_archived_v1">>,
      <<"venture_id">> => <<"vent-1">>,
      <<"archived_at">> => 4000}.

%% ===================================================================
%% Layer 2b: Handler Tests (Business Logic)
%% ===================================================================

%% maybe_setup_venture
handle_valid_setup_test() ->
    {ok, Cmd} = setup_venture_v1:new(#{
        name => <<"Test Venture">>,
        venture_id => <<"vent-1">>,
        initiated_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_setup_venture:handle(Cmd),
    Map = venture_setup_v1:to_map(Event),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"Test Venture">>, maps:get(<<"name">>, Map)),
    ?assertEqual(<<"user@host">>, maps:get(<<"initiated_by">>, Map)).

%% maybe_refine_vision
handle_valid_refine_test() ->
    {ok, Cmd} = refine_vision_v1:new(#{
        venture_id => <<"vent-1">>,
        brief => <<"New brief">>,
        repos => [<<"repo1">>]
    }),
    {ok, [Event]} = maybe_refine_vision:handle(Cmd),
    Map = venture_vision_refined_v1:to_map(Event),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"New brief">>, maps:get(<<"brief">>, Map)),
    ?assertEqual([<<"repo1">>], maps:get(<<"repos">>, Map)).

%% maybe_submit_vision
handle_valid_submit_test() ->
    {ok, Cmd} = submit_vision_v1:new(#{
        venture_id => <<"vent-1">>,
        submitted_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_submit_vision:handle(Cmd),
    Map = venture_vision_submitted_v1:to_map(Event),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"user@host">>, maps:get(<<"submitted_by">>, Map)).

%% maybe_archive_venture
handle_valid_archive_test() ->
    {ok, Cmd} = archive_venture_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    {ok, [Event]} = maybe_archive_venture:handle(Cmd),
    Map = venture_archived_v1:to_map(Event),
    ?assertEqual(<<"vent-1">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"admin">>, maps:get(<<"archived_by">>, Map)),
    ?assertEqual(<<"cleanup">>, maps:get(<<"reason">>, Map)).

%% ===================================================================
%% Layer 2c: Aggregate execute/2 State Machine Tests
%% ===================================================================

%% --- setup_venture command ---

execute_setup_on_fresh_state_test() ->
    Cmd = #{<<"command_type">> => <<"setup_venture">>,
            <<"name">> => <<"New Venture">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = setup_aggregate:execute(fresh_state(), Cmd),
    ?assertEqual(<<"venture_setup_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_setup_already_setup_test() ->
    Cmd = #{<<"command_type">> => <<"setup_venture">>,
            <<"name">> => <<"Another">>,
            <<"venture_id">> => <<"vent-2">>},
    ?assertEqual({error, venture_already_setup},
                 setup_aggregate:execute(setup_state(), Cmd)).

%% --- refine_vision command ---

execute_refine_on_setup_state_test() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"brief">> => <<"Refined brief">>},
    {ok, [EventMap]} = setup_aggregate:execute(setup_state(), Cmd),
    ?assertEqual(<<"venture_vision_refined_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_refine_not_found_test() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, venture_not_found},
                 setup_aggregate:execute(fresh_state(), Cmd)).

execute_refine_after_archive_test() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, venture_archived},
                 setup_aggregate:execute(archived_state(), Cmd)).

execute_refine_after_submit_test() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, vision_already_submitted},
                 setup_aggregate:execute(submitted_state(), Cmd)).

%% --- submit_vision command ---

execute_submit_on_setup_state_test() ->
    Cmd = #{<<"command_type">> => <<"submit_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = setup_aggregate:execute(setup_state(), Cmd),
    ?assertEqual(<<"venture_vision_submitted_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_submit_not_found_test() ->
    Cmd = #{<<"command_type">> => <<"submit_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, venture_not_found},
                 setup_aggregate:execute(fresh_state(), Cmd)).

execute_submit_already_submitted_test() ->
    Cmd = #{<<"command_type">> => <<"submit_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, vision_already_submitted},
                 setup_aggregate:execute(submitted_state(), Cmd)).

execute_submit_after_archive_test() ->
    Cmd = #{<<"command_type">> => <<"submit_vision">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, venture_archived},
                 setup_aggregate:execute(archived_state(), Cmd)).

%% --- archive_venture command ---

execute_archive_on_setup_state_test() ->
    Cmd = #{<<"command_type">> => <<"archive_venture">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = setup_aggregate:execute(setup_state(), Cmd),
    ?assertEqual(<<"venture_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

execute_archive_not_found_test() ->
    Cmd = #{<<"command_type">> => <<"archive_venture">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, venture_not_found},
                 setup_aggregate:execute(fresh_state(), Cmd)).

execute_archive_already_archived_test() ->
    Cmd = #{<<"command_type">> => <<"archive_venture">>,
            <<"venture_id">> => <<"vent-1">>},
    ?assertEqual({error, venture_already_archived},
                 setup_aggregate:execute(archived_state(), Cmd)).

%% Archive doesn't check for submitted — can archive at any point after setup
execute_archive_after_submit_test() ->
    Cmd = #{<<"command_type">> => <<"archive_venture">>,
            <<"venture_id">> => <<"vent-1">>},
    {ok, [EventMap]} = setup_aggregate:execute(submitted_state(), Cmd),
    ?assertEqual(<<"venture_archived_v1">>, maps:get(<<"event_type">>, EventMap)).

%% --- unknown command ---

execute_unknown_command_test() ->
    Cmd = #{<<"command_type">> => <<"unknown_thing">>},
    ?assertEqual({error, unknown_command},
                 setup_aggregate:execute(fresh_state(), Cmd)).

execute_missing_command_type_test() ->
    ?assertEqual({error, unknown_command},
                 setup_aggregate:execute(fresh_state(), #{<<"data">> => <<"stuff">>})).

%% --- evoq callback order: execute(State, Payload) ---

execute_evoq_callback_order_test() ->
    State = fresh_state(),
    Payload = #{<<"command_type">> => <<"setup_venture">>,
                <<"name">> => <<"Order Test">>,
                <<"venture_id">> => <<"vent-order">>},
    %% Correct order: State first, Payload second
    {ok, _Events} = setup_aggregate:execute(State, Payload).

%% Refine on refined state should still work (can refine multiple times)
execute_refine_on_refined_state_test() ->
    Cmd = #{<<"command_type">> => <<"refine_vision">>,
            <<"venture_id">> => <<"vent-1">>,
            <<"brief">> => <<"Second refinement">>},
    {ok, [EventMap]} = setup_aggregate:execute(refined_state(), Cmd),
    ?assertEqual(<<"venture_vision_refined_v1">>, maps:get(<<"event_type">>, EventMap)).
