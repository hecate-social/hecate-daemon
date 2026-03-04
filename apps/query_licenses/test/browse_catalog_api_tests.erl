%%% @doc Tests for browse_catalog_api:row_to_map/1.
%%%
%%% Verifies row_to_map handles esqlite3 list rows and tuple rows.
%%% @end
-module(browse_catalog_api_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- List row (what esqlite3 actually returns) --

list_row_test() ->
    Row = [<<"hecate-apps/snake-duel">>, <<"Snake Duel">>, <<"hecate-apps">>,
           <<"0.1.1">>, <<"Snake arena game">>, <<"snake">>,
           <<"ghcr.io/hecate-apps/hecate-app-snake-dueld:0.1.1">>,
           <<"snake-duel-studio">>, <<"game,arcade">>, <<"https://github.com/hecate-apps">>,
           <<"0.14.0">>, <<"did:macula:pub123">>, <<"free">>,
           <<"free">>, 0, <<"EUR">>, 0, 0,
           1772600000000, 1772600000000, 1772600000000,
           4, 0,
           undefined, 0, undefined],
    Map = browse_catalog_api:row_to_map(Row),
    ?assertEqual(<<"hecate-apps/snake-duel">>, maps:get(plugin_id, Map)),
    ?assertEqual(<<"Snake Duel">>, maps:get(name, Map)),
    ?assertEqual(<<"hecate-apps">>, maps:get(org, Map)),
    ?assertEqual(<<"EUR">>, maps:get(fee_currency, Map)),
    ?assertEqual(26, maps:size(Map)).

%% -- Tuple row (backward compat) --

tuple_row_test() ->
    Row = list_to_tuple(lists:duplicate(26, <<"val">>)),
    Map = browse_catalog_api:row_to_map(Row),
    ?assertEqual(26, maps:size(Map)).

%% -- Column mismatch crashes --

column_mismatch_crashes_test() ->
    TooFew = [<<"a">>, <<"b">>],
    ?assertError(_, browse_catalog_api:row_to_map(TooFew)).
