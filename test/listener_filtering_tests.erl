%%%-------------------------------------------------------------------
%%% @doc Tests for listener identity filtering logic.
%%%
%%% These tests verify that listeners correctly filter mesh facts
%%% based on the managed_identities configuration.
%%% @end
%%%-------------------------------------------------------------------
-module(listener_filtering_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

is_my_identity_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"returns true for managed identity", fun matches_managed_identity/0},
            {"returns false for unknown identity", fun rejects_unknown_identity/0},
            {"handles empty managed list", fun handles_empty_list/0},
            {"handles multiple managed identities", fun handles_multiple_identities/0},
            {"is case sensitive", fun is_case_sensitive/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    ok.

cleanup(_) ->
    application:unset_env(hecate, managed_identities),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

matches_managed_identity() ->
    ManagedIdentities = [
        <<"mri:agent:io.macula/gateway">>,
        <<"mri:agent:io.macula/gateway/weather">>
    ],
    application:set_env(hecate, managed_identities, ManagedIdentities),

    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/gateway">>)),
    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/gateway/weather">>)).

rejects_unknown_identity() ->
    ManagedIdentities = [<<"mri:agent:io.macula/gateway">>],
    application:set_env(hecate, managed_identities, ManagedIdentities),

    ?assertEqual(false, is_my_identity(<<"mri:agent:io.macula/other">>)),
    ?assertEqual(false, is_my_identity(<<"mri:agent:io.macula/gateway/unknown">>)).

handles_empty_list() ->
    application:set_env(hecate, managed_identities, []),

    ?assertEqual(false, is_my_identity(<<"mri:agent:io.macula/gateway">>)).

handles_multiple_identities() ->
    ManagedIdentities = [
        <<"mri:agent:io.macula/gateway">>,
        <<"mri:agent:io.macula/gateway/weather">>,
        <<"mri:agent:io.macula/gateway/translation">>,
        <<"mri:agent:io.macula/gateway/data-api">>
    ],
    application:set_env(hecate, managed_identities, ManagedIdentities),

    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/gateway">>)),
    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/gateway/weather">>)),
    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/gateway/translation">>)),
    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/gateway/data-api">>)),
    ?assertEqual(false, is_my_identity(<<"mri:agent:io.macula/gateway/unknown">>)).

is_case_sensitive() ->
    ManagedIdentities = [<<"mri:agent:io.macula/Gateway">>],
    application:set_env(hecate, managed_identities, ManagedIdentities),

    ?assertEqual(true, is_my_identity(<<"mri:agent:io.macula/Gateway">>)),
    ?assertEqual(false, is_my_identity(<<"mri:agent:io.macula/gateway">>)),
    ?assertEqual(false, is_my_identity(<<"mri:agent:io.macula/GATEWAY">>)).

%%====================================================================
%% Helper (same as in listeners)
%%====================================================================

is_my_identity(Identity) ->
    ManagedIdentities = application:get_env(hecate, managed_identities, []),
    lists:member(Identity, ManagedIdentities).
