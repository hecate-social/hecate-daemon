%%% @doc Tests for maybe_stage_rollout handler and stage_rollout_v1 command.
%%% Covers valid rollout staging and empty division_id rejection.
-module(stage_rollout_tests).

-include_lib("eunit/include/eunit.hrl").

stage_rollout_test_() ->
    [
        {"valid: handler returns event with stage details", fun valid_stage_rollout/0},
        {"empty_division_id: command rejected",             fun empty_division_id/0}
    ].

valid_stage_rollout() ->
    {ok, Cmd} = stage_rollout_v1:new(#{
        division_id => <<"div-1">>,
        stage_id => <<"stg-1">>,
        release_id => <<"rel-1">>,
        stage_name => <<"canary">>
    }),
    {ok, [Event]} = maybe_stage_rollout:handle(Cmd),
    Map = rollout_staged_v1:to_map(Event),
    ?assertEqual(<<"stg-1">>, maps:get(<<"stage_id">>, Map)),
    ?assertEqual(<<"canary">>, maps:get(<<"stage_name">>, Map)),
    ?assertEqual(<<"rollout_staged_v1">>, maps:get(<<"event_type">>, Map)).

empty_division_id() ->
    {ok, Cmd} = stage_rollout_v1:new(#{
        division_id => <<>>,
        stage_id => <<"stg-1">>,
        release_id => <<"rel-1">>,
        stage_name => <<"canary">>
    }),
    ?assertEqual({error, invalid_division_id},
                 maybe_stage_rollout:handle(Cmd)).
