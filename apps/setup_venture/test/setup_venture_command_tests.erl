%%% @doc Layer 2a: Command module tests.
%%% Tests new/1, from_map/1, validate/1, to_map/1, accessors, round-trips
%%% for all 4 command modules.
-module(setup_venture_command_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% setup_venture_v1 command tests
%% ===================================================================

setup_venture_new_valid_test() ->
    {ok, Cmd} = setup_venture_v1:new(#{name => <<"My Venture">>}),
    ?assertEqual(<<"My Venture">>, setup_venture_v1:get_name(Cmd)),
    %% venture_id auto-generated
    VId = setup_venture_v1:get_venture_id(Cmd),
    ?assert(is_binary(VId)),
    ?assertMatch(<<"venture-", _/binary>>, VId).

setup_venture_new_with_all_fields_test() ->
    {ok, Cmd} = setup_venture_v1:new(#{
        name => <<"Full">>,
        venture_id => <<"vent-custom">>,
        brief => <<"A brief">>,
        initiated_by => <<"user@host">>
    }),
    ?assertEqual(<<"Full">>, setup_venture_v1:get_name(Cmd)),
    ?assertEqual(<<"vent-custom">>, setup_venture_v1:get_venture_id(Cmd)),
    ?assertEqual(<<"A brief">>, setup_venture_v1:get_brief(Cmd)),
    ?assertEqual(<<"user@host">>, setup_venture_v1:get_initiated_by(Cmd)).

setup_venture_new_missing_name_test() ->
    ?assertEqual({error, missing_required_fields}, setup_venture_v1:new(#{})).

setup_venture_from_map_binary_keys_test() ->
    {ok, Cmd} = setup_venture_v1:from_map(#{
        <<"name">> => <<"Bin Venture">>,
        <<"venture_id">> => <<"vent-bin">>,
        <<"brief">> => <<"bin brief">>
    }),
    ?assertEqual(<<"Bin Venture">>, setup_venture_v1:get_name(Cmd)),
    ?assertEqual(<<"vent-bin">>, setup_venture_v1:get_venture_id(Cmd)).

setup_venture_from_map_atom_keys_test() ->
    {ok, Cmd} = setup_venture_v1:from_map(#{
        name => <<"Atom Venture">>,
        venture_id => <<"vent-atom">>
    }),
    ?assertEqual(<<"Atom Venture">>, setup_venture_v1:get_name(Cmd)).

setup_venture_from_map_missing_name_test() ->
    ?assertEqual({error, missing_required_fields},
                 setup_venture_v1:from_map(#{<<"venture_id">> => <<"vent-1">>})).

setup_venture_to_map_round_trip_test() ->
    {ok, Cmd} = setup_venture_v1:new(#{
        name => <<"RT">>,
        venture_id => <<"vent-rt">>,
        brief => <<"brief">>,
        initiated_by => <<"user">>
    }),
    Map = setup_venture_v1:to_map(Cmd),
    ?assertEqual(<<"setup_venture">>, maps:get(<<"command_type">>, Map)),
    ?assertEqual(<<"vent-rt">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"RT">>, maps:get(<<"name">>, Map)),
    ?assertEqual(<<"brief">>, maps:get(<<"brief">>, Map)),
    %% Round-trip: to_map -> from_map preserves fields
    {ok, Cmd2} = setup_venture_v1:from_map(Map),
    ?assertEqual(setup_venture_v1:get_name(Cmd), setup_venture_v1:get_name(Cmd2)),
    ?assertEqual(setup_venture_v1:get_venture_id(Cmd), setup_venture_v1:get_venture_id(Cmd2)).

setup_venture_validate_valid_test() ->
    {ok, Cmd} = setup_venture_v1:new(#{name => <<"Valid">>}),
    ?assertMatch({ok, _}, setup_venture_v1:validate(Cmd)).

setup_venture_generate_id_uniqueness_test() ->
    Id1 = setup_venture_v1:generate_id(),
    Id2 = setup_venture_v1:generate_id(),
    ?assertNotEqual(Id1, Id2),
    ?assertMatch(<<"venture-", _/binary>>, Id1).

%% ===================================================================
%% refine_vision_v1 command tests
%% ===================================================================

refine_vision_new_valid_test() ->
    {ok, Cmd} = refine_vision_v1:new(#{venture_id => <<"vent-1">>}),
    ?assertEqual(<<"vent-1">>, refine_vision_v1:get_venture_id(Cmd)),
    ?assertEqual(undefined, refine_vision_v1:get_brief(Cmd)).

refine_vision_new_with_all_fields_test() ->
    {ok, Cmd} = refine_vision_v1:new(#{
        venture_id => <<"vent-1">>,
        brief => <<"new brief">>,
        repos => [<<"r1">>],
        skills => [<<"s1">>],
        context_map => #{<<"a">> => 1},
        refined_by => <<"user">>
    }),
    ?assertEqual(<<"new brief">>, refine_vision_v1:get_brief(Cmd)),
    ?assertEqual([<<"r1">>], refine_vision_v1:get_repos(Cmd)),
    ?assertEqual([<<"s1">>], refine_vision_v1:get_skills(Cmd)),
    ?assertEqual(#{<<"a">> => 1}, refine_vision_v1:get_context_map(Cmd)),
    ?assertEqual(<<"user">>, refine_vision_v1:get_refined_by(Cmd)).

refine_vision_new_missing_venture_id_test() ->
    ?assertEqual({error, missing_required_fields}, refine_vision_v1:new(#{})).

refine_vision_from_map_binary_keys_test() ->
    {ok, Cmd} = refine_vision_v1:from_map(#{
        <<"venture_id">> => <<"vent-1">>,
        <<"brief">> => <<"updated">>
    }),
    ?assertEqual(<<"vent-1">>, refine_vision_v1:get_venture_id(Cmd)),
    ?assertEqual(<<"updated">>, refine_vision_v1:get_brief(Cmd)).

refine_vision_to_map_round_trip_test() ->
    {ok, Cmd} = refine_vision_v1:new(#{
        venture_id => <<"vent-1">>,
        brief => <<"b">>,
        repos => [<<"r">>]
    }),
    Map = refine_vision_v1:to_map(Cmd),
    ?assertEqual(<<"refine_vision">>, maps:get(<<"command_type">>, Map)),
    {ok, Cmd2} = refine_vision_v1:from_map(Map),
    ?assertEqual(refine_vision_v1:get_venture_id(Cmd), refine_vision_v1:get_venture_id(Cmd2)),
    ?assertEqual(refine_vision_v1:get_brief(Cmd), refine_vision_v1:get_brief(Cmd2)).

%% ===================================================================
%% submit_vision_v1 command tests
%% ===================================================================

submit_vision_new_valid_test() ->
    {ok, Cmd} = submit_vision_v1:new(#{venture_id => <<"vent-1">>}),
    ?assertEqual(<<"vent-1">>, submit_vision_v1:get_venture_id(Cmd)),
    ?assertEqual(undefined, submit_vision_v1:get_submitted_by(Cmd)).

submit_vision_new_with_all_fields_test() ->
    {ok, Cmd} = submit_vision_v1:new(#{
        venture_id => <<"vent-1">>,
        submitted_by => <<"user@host">>
    }),
    ?assertEqual(<<"user@host">>, submit_vision_v1:get_submitted_by(Cmd)).

submit_vision_new_missing_venture_id_test() ->
    ?assertEqual({error, missing_required_fields}, submit_vision_v1:new(#{})).

submit_vision_from_map_binary_keys_test() ->
    {ok, Cmd} = submit_vision_v1:from_map(#{<<"venture_id">> => <<"vent-1">>}),
    ?assertEqual(<<"vent-1">>, submit_vision_v1:get_venture_id(Cmd)).

submit_vision_to_map_round_trip_test() ->
    {ok, Cmd} = submit_vision_v1:new(#{
        venture_id => <<"vent-1">>,
        submitted_by => <<"user">>
    }),
    Map = submit_vision_v1:to_map(Cmd),
    ?assertEqual(<<"submit_vision">>, maps:get(<<"command_type">>, Map)),
    {ok, Cmd2} = submit_vision_v1:from_map(Map),
    ?assertEqual(submit_vision_v1:get_venture_id(Cmd), submit_vision_v1:get_venture_id(Cmd2)),
    ?assertEqual(submit_vision_v1:get_submitted_by(Cmd), submit_vision_v1:get_submitted_by(Cmd2)).

%% ===================================================================
%% archive_venture_v1 command tests
%% ===================================================================

archive_venture_new_valid_test() ->
    {ok, Cmd} = archive_venture_v1:new(#{venture_id => <<"vent-1">>}),
    ?assertEqual(<<"vent-1">>, archive_venture_v1:get_venture_id(Cmd)),
    ?assertEqual(undefined, archive_venture_v1:get_archived_by(Cmd)),
    ?assertEqual(undefined, archive_venture_v1:get_reason(Cmd)).

archive_venture_new_with_all_fields_test() ->
    {ok, Cmd} = archive_venture_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"cleanup">>
    }),
    ?assertEqual(<<"admin">>, archive_venture_v1:get_archived_by(Cmd)),
    ?assertEqual(<<"cleanup">>, archive_venture_v1:get_reason(Cmd)).

archive_venture_new_missing_venture_id_test() ->
    ?assertEqual({error, missing_required_fields}, archive_venture_v1:new(#{})).

archive_venture_from_map_binary_keys_test() ->
    {ok, Cmd} = archive_venture_v1:from_map(#{
        <<"venture_id">> => <<"vent-1">>,
        <<"reason">> => <<"bye">>
    }),
    ?assertEqual(<<"vent-1">>, archive_venture_v1:get_venture_id(Cmd)),
    ?assertEqual(<<"bye">>, archive_venture_v1:get_reason(Cmd)).

archive_venture_to_map_round_trip_test() ->
    {ok, Cmd} = archive_venture_v1:new(#{
        venture_id => <<"vent-1">>,
        archived_by => <<"admin">>,
        reason => <<"done">>
    }),
    Map = archive_venture_v1:to_map(Cmd),
    ?assertEqual(<<"archive_venture">>, maps:get(<<"command_type">>, Map)),
    {ok, Cmd2} = archive_venture_v1:from_map(Map),
    ?assertEqual(archive_venture_v1:get_venture_id(Cmd), archive_venture_v1:get_venture_id(Cmd2)),
    ?assertEqual(archive_venture_v1:get_reason(Cmd), archive_venture_v1:get_reason(Cmd2)).
