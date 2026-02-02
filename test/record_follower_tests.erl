%%%-------------------------------------------------------------------
%%% @doc Tests for record_follower command and handler.
%%%
%%% Tests the command that records when someone follows one of my identities.
%%% @end
%%%-------------------------------------------------------------------
-module(record_follower_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

record_follower_command_test_() ->
    [
        {"creates valid command", fun creates_valid_command/0},
        {"to_map returns all fields", fun to_map_returns_all_fields/0},
        {"from_map reconstructs command", fun from_map_reconstructs/0},
        {"from_map rejects invalid input", fun from_map_rejects_invalid/0}
    ].

maybe_record_follower_test_() ->
    [
        {"handle produces event on valid command", fun handle_produces_event/0},
        {"handle rejects self-follow", fun handle_rejects_self_follow/0}
    ].

%%====================================================================
%% Command Tests
%%====================================================================

creates_valid_command() ->
    Cmd = record_follower_v1:new(
        <<"mri:agent:io.macula/other">>,
        <<"mri:agent:io.macula/me">>,
        1706800000000
    ),
    ?assertNotEqual(undefined, Cmd).

to_map_returns_all_fields() ->
    Cmd = record_follower_v1:new(
        <<"follower-id">>,
        <<"my-id">>,
        1706800000000
    ),
    Map = record_follower_v1:to_map(Cmd),

    ?assertEqual(<<"follower-id">>, maps:get(follower_identity, Map)),
    ?assertEqual(<<"my-id">>, maps:get(my_identity, Map)),
    ?assertEqual(1706800000000, maps:get(followed_at, Map)).

from_map_reconstructs() ->
    Original = record_follower_v1:new(
        <<"follower-id">>,
        <<"my-id">>,
        1706800000000
    ),
    Map = record_follower_v1:to_map(Original),
    {ok, Reconstructed} = record_follower_v1:from_map(Map),

    ?assertEqual(
        record_follower_v1:to_map(Original),
        record_follower_v1:to_map(Reconstructed)
    ).

from_map_rejects_invalid() ->
    ?assertEqual(
        {error, invalid_record_follower_command},
        record_follower_v1:from_map(#{})
    ),
    ?assertEqual(
        {error, invalid_record_follower_command},
        record_follower_v1:from_map(#{follower_identity => <<"id">>})
    ).

%%====================================================================
%% Handler Tests
%%====================================================================

handle_produces_event() ->
    Cmd = record_follower_v1:new(
        <<"mri:agent:io.macula/other">>,
        <<"mri:agent:io.macula/me">>,
        1706800000000
    ),

    {ok, [EventMap]} = maybe_record_follower:handle(Cmd),

    ?assertEqual(<<"mri:agent:io.macula/other">>, maps:get(follower_identity, EventMap)),
    ?assertEqual(<<"mri:agent:io.macula/me">>, maps:get(my_identity, EventMap)),
    ?assertEqual(1706800000000, maps:get(followed_at, EventMap)),
    ?assert(maps:is_key(recorded_at, EventMap)).

handle_rejects_self_follow() ->
    Cmd = record_follower_v1:new(
        <<"mri:agent:io.macula/me">>,  %% Same as my_identity
        <<"mri:agent:io.macula/me">>,
        1706800000000
    ),

    ?assertEqual({error, cannot_record_self_follow}, maybe_record_follower:handle(Cmd)).
