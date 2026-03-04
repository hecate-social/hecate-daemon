%%% @doc Tests for get_licenses_page_api:row_to_map/1.
%%%
%%% Verifies row_to_map handles esqlite3 list rows and tuple rows.
%%% @end
-module(get_licenses_page_api_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- List row (what esqlite3 actually returns) --

list_row_test() ->
    Row = [<<"lic-abc">>, <<"user-1">>, <<"hecate-apps/trader">>, <<"Trader">>,
           1, <<"0.1.0">>, <<"ghcr.io/hecate-apps/hecate-traderd:latest">>,
           1772600000000, 1772610000000, undefined, 0, undefined],
    Map = get_licenses_page_api:row_to_map(Row),
    ?assertEqual(<<"lic-abc">>, maps:get(license_id, Map)),
    ?assertEqual(<<"user-1">>, maps:get(user_id, Map)),
    ?assertEqual(<<"hecate-apps/trader">>, maps:get(plugin_id, Map)),
    ?assertEqual(<<"Trader">>, maps:get(plugin_name, Map)),
    ?assertEqual(1, maps:get(installed, Map)),
    ?assertEqual(0, maps:get(revoked, Map)),
    ?assertEqual(12, maps:size(Map)).

%% -- Tuple row (backward compat) --

tuple_row_test() ->
    Row = list_to_tuple(lists:duplicate(12, <<"val">>)),
    Map = get_licenses_page_api:row_to_map(Row),
    ?assertEqual(12, maps:size(Map)).

%% -- Column mismatch crashes --

column_mismatch_crashes_test() ->
    TooFew = [<<"a">>],
    ?assertError(_, get_licenses_page_api:row_to_map(TooFew)).
