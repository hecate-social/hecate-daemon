%%% @doc Tests for get_catalog_entry_api:row_to_map/2.
%%%
%%% This module uses row_to_map/2 (takes Columns as first arg)
%%% for both catalog and license column sets.
%%% @end
-module(get_catalog_entry_api_tests).

-include_lib("eunit/include/eunit.hrl").

%% -- Catalog columns: list row --

catalog_list_row_test() ->
    Columns = [plugin_id, name, org],
    Row = [<<"hecate-apps/snake-duel">>, <<"Snake Duel">>, <<"hecate-apps">>],
    Map = get_catalog_entry_api:row_to_map(Columns, Row),
    ?assertEqual(<<"hecate-apps/snake-duel">>, maps:get(plugin_id, Map)),
    ?assertEqual(<<"Snake Duel">>, maps:get(name, Map)),
    ?assertEqual(<<"hecate-apps">>, maps:get(org, Map)),
    ?assertEqual(3, maps:size(Map)).

%% -- Catalog columns: tuple row --

catalog_tuple_row_test() ->
    Columns = [plugin_id, name, org],
    Row = {<<"id">>, <<"name">>, <<"org">>},
    Map = get_catalog_entry_api:row_to_map(Columns, Row),
    ?assertEqual(3, maps:size(Map)),
    ?assertEqual(<<"id">>, maps:get(plugin_id, Map)).

%% -- Full catalog column set --

full_catalog_columns_test() ->
    Columns = [
        plugin_id, license_id, name, org, version, description, icon,
        github_repo, oci_image, manifest_tag, tags, homepage,
        min_daemon_version, publisher_identity, selling_formula, seller_id,
        license_type, fee_cents, fee_currency, duration_days, node_limit,
        announced_at, published_at, cataloged_at, refreshed_at,
        status, status_label, retracted
    ],
    Row = lists:duplicate(28, <<"val">>),
    Map = get_catalog_entry_api:row_to_map(Columns, Row),
    ?assertEqual(28, maps:size(Map)).

%% -- Column mismatch crashes --

column_mismatch_crashes_test() ->
    Columns = [a, b, c],
    Row = [1, 2],
    ?assertError(_, get_catalog_entry_api:row_to_map(Columns, Row)).
