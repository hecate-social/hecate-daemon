%%% @doc Tests for list_plugins_api:row_to_map/1.
%%%
%%% esqlite3:fetchall returns lists, not tuples. These tests
%%% verify row_to_map handles both formats correctly.
%%% @end
-module(list_plugins_api_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- List row (what esqlite3 actually returns) --

list_row_test() ->
    Row = [<<"hecate-apps/snake-duel">>, <<"snake-duel">>,
           <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>,
           <<"0.1.1">>, undefined, 1772617342486, undefined, 1, <<"Installed">>],
    Map = list_plugins_api:row_to_map(Row),
    ?assertEqual(<<"hecate-apps/snake-duel">>, maps:get(plugin_id, Map)),
    ?assertEqual(<<"snake-duel">>, maps:get(name, Map)),
    ?assertEqual(<<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>, maps:get(oci_image, Map)),
    ?assertEqual(<<"0.1.1">>, maps:get(installed_version, Map)),
    ?assertEqual(undefined, maps:get(license_id, Map)),
    ?assertEqual(1772617342486, maps:get(installed_at, Map)),
    ?assertEqual(undefined, maps:get(upgraded_at, Map)),
    ?assertEqual(1, maps:get(status, Map)),
    ?assertEqual(<<"Installed">>, maps:get(status_label, Map)).

%% -- Tuple row (backward compat) --

tuple_row_test() ->
    Row = {<<"hecate-apps/trader">>, <<"trader">>,
           <<"ghcr.io/hecate-apps/hecate-traderd:latest">>,
           <<"0.1.0">>, <<"lic-123">>, 1772600000000, undefined, 1, <<"Installed">>},
    Map = list_plugins_api:row_to_map(Row),
    ?assertEqual(<<"hecate-apps/trader">>, maps:get(plugin_id, Map)),
    ?assertEqual(<<"trader">>, maps:get(name, Map)),
    ?assertEqual(<<"lic-123">>, maps:get(license_id, Map)).

%% -- All 9 columns present --

column_count_test() ->
    Row = [<<"a">>, <<"b">>, <<"c">>, <<"d">>, <<"e">>, 1, 2, 3, <<"f">>],
    Map = list_plugins_api:row_to_map(Row),
    ?assertEqual(9, maps:size(Map)).

%% -- Column mismatch crashes (not silent corruption) --

column_mismatch_crashes_test() ->
    TooFew = [<<"a">>, <<"b">>],
    ?assertError(_, list_plugins_api:row_to_map(TooFew)).
