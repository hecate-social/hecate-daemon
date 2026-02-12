%%% @doc Tests for maybe_apply_fix handler and apply_fix_v1 command.
%%% Covers valid fix application with description and empty division_id rejection.
-module(apply_fix_tests).

-include_lib("eunit/include/eunit.hrl").

apply_fix_test_() ->
    [
        {"valid: handler returns event with description", fun valid_apply_fix/0},
        {"empty_division_id: command rejected",           fun empty_division_id/0}
    ].

valid_apply_fix() ->
    {ok, Cmd} = apply_fix_v1:new(#{
        division_id => <<"div-1">>,
        fix_id => <<"fix-1">>,
        incident_id => <<"inc-1">>,
        description => <<"Bumped memory">>
    }),
    {ok, [Event]} = maybe_apply_fix:handle(Cmd),
    Map = fix_applied_v1:to_map(Event),
    ?assertEqual(<<"Bumped memory">>, maps:get(<<"description">>, Map)),
    ?assertEqual(<<"fix-1">>, maps:get(<<"fix_id">>, Map)),
    ?assertEqual(<<"fix_applied_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = apply_fix_v1:new(#{
        division_id => <<>>,
        fix_id => <<"fix-1">>,
        incident_id => <<"inc-1">>,
        description => <<"Bumped memory">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_apply_fix:handle(Cmd)).
