%%%-------------------------------------------------------------------
%%% @doc Tests for receive_capability command and handler.
%%%
%%% SECURITY-CRITICAL: Tests the command that records incoming UCAN capability grants.
%%% @end
%%%-------------------------------------------------------------------
-module(receive_capability_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

receive_capability_command_test_() ->
    [
        {"creates valid command with all fields", fun creates_valid_command/0},
        {"to_map returns all fields", fun to_map_returns_all_fields/0},
        {"from_map reconstructs command", fun from_map_reconstructs/0},
        {"handles optional token_cid", fun handles_optional_token_cid/0}
    ].

maybe_receive_capability_test_() ->
    [
        {"handle produces event on valid command", fun handle_produces_event/0},
        {"handle rejects self-granted capability", fun handle_rejects_self_grant/0}
    ].

%%====================================================================
%% Command Tests
%%====================================================================

creates_valid_command() ->
    Cmd = receive_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/me">>,
        <<"mri:resource:io.macula/data/*">>,
        [<<"read">>, <<"write">>],
        1706900000000,
        1706800000000,
        <<"bafytoken123">>
    ),
    ?assertNotEqual(undefined, Cmd).

to_map_returns_all_fields() ->
    Cmd = receive_capability_v1:new(
        <<"cap-123">>,
        <<"issuer-id">>,
        <<"my-id">>,
        <<"resource-mri">>,
        [<<"read">>],
        1706900000000,
        1706800000000,
        <<"token-cid">>
    ),
    Map = receive_capability_v1:to_map(Cmd),

    ?assertEqual(<<"cap-123">>, maps:get(capability_id, Map)),
    ?assertEqual(<<"issuer-id">>, maps:get(issuer, Map)),
    ?assertEqual(<<"my-id">>, maps:get(my_identity, Map)),
    ?assertEqual(<<"resource-mri">>, maps:get(resource, Map)),
    ?assertEqual([<<"read">>], maps:get(actions, Map)),
    ?assertEqual(1706900000000, maps:get(expires_at, Map)),
    ?assertEqual(1706800000000, maps:get(granted_at, Map)),
    ?assertEqual(<<"token-cid">>, maps:get(token_cid, Map)).

from_map_reconstructs() ->
    Original = receive_capability_v1:new(
        <<"cap-456">>,
        <<"issuer">>,
        <<"audience">>,
        <<"resource">>,
        [<<"execute">>],
        1706900000000,
        1706800000000,
        <<"cid">>
    ),
    Map = receive_capability_v1:to_map(Original),
    {ok, Reconstructed} = receive_capability_v1:from_map(Map),

    ?assertEqual(
        receive_capability_v1:to_map(Original),
        receive_capability_v1:to_map(Reconstructed)
    ).

handles_optional_token_cid() ->
    %% token_cid can be undefined
    Cmd = receive_capability_v1:new(
        <<"cap-789">>,
        <<"issuer">>,
        <<"audience">>,
        <<"resource">>,
        [<<"read">>],
        1706900000000,
        1706800000000,
        undefined
    ),
    Map = receive_capability_v1:to_map(Cmd),

    ?assertEqual(undefined, maps:get(token_cid, Map)).

%%====================================================================
%% Handler Tests
%%====================================================================

handle_produces_event() ->
    Cmd = receive_capability_v1:new(
        <<"cap-123">>,
        <<"mri:agent:io.macula/issuer">>,
        <<"mri:agent:io.macula/me">>,
        <<"mri:resource:io.macula/data/*">>,
        [<<"read">>, <<"write">>],
        1706900000000,
        1706800000000,
        <<"bafytoken123">>
    ),

    {ok, [EventMap]} = maybe_receive_capability:handle(Cmd),

    ?assertEqual(<<"cap-123">>, maps:get(capability_id, EventMap)),
    ?assertEqual(<<"mri:agent:io.macula/issuer">>, maps:get(issuer, EventMap)),
    ?assertEqual(<<"mri:agent:io.macula/me">>, maps:get(my_identity, EventMap)),
    ?assertEqual(<<"mri:resource:io.macula/data/*">>, maps:get(resource, EventMap)),
    ?assertEqual([<<"read">>, <<"write">>], maps:get(actions, EventMap)),
    ?assert(maps:is_key(recorded_at, EventMap)).

handle_rejects_self_grant() ->
    %% SECURITY: Cannot receive capability granted by yourself from mesh
    Cmd = receive_capability_v1:new(
        <<"cap-self">>,
        <<"mri:agent:io.macula/me">>,  %% Same as my_identity
        <<"mri:agent:io.macula/me">>,
        <<"resource">>,
        [<<"read">>],
        1706900000000,
        1706800000000,
        undefined
    ),

    ?assertEqual(
        {error, cannot_receive_self_granted_capability},
        maybe_receive_capability:handle(Cmd)
    ).
