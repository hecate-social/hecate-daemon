-module(generation_projection_tests).
-include_lib("eunit/include/eunit.hrl").
-include_lib("generate_division/include/generation_status.hrl").

projection_test_() ->
    {foreach, fun setup/0, fun teardown/1, [
      fun correct_flags/1, fun label_correct/1, fun archive_bits/1, fun mod_fields/1
    ]}.
setup() -> application:ensure_all_started(esqlite),
    {ok, _} = generations_test_store_proxy:start("/tmp/test_proj_gen_" ++ integer_to_list(erlang:unique_integer([positive])) ++ ".db"), #{}.
teardown(#{}) -> generations_test_store_proxy:stop(), ok.

correct_flags(#{}) -> fun() ->
    ok = generation_started_v1_to_sqlite_generations:project(#{<<"division_id">> => <<"d-sf">>, <<"started_at">> => 1000}),
    {ok, [{_, Status, _, _, _}]} = query_generations_store:query(
        "SELECT division_id, status, status_label, started_at, started_by FROM generations WHERE division_id = ?1", [<<"d-sf">>]),
    ?assertEqual(?GENERATION_INITIATED bor ?GENERATION_ACTIVE, Status) end.

label_correct(#{}) -> fun() ->
    ok = generation_started_v1_to_sqlite_generations:project(#{<<"division_id">> => <<"d-lb">>, <<"started_at">> => 1000}),
    {ok, [{Status, Label}]} = query_generations_store:query("SELECT status, status_label FROM generations WHERE division_id = ?1", [<<"d-lb">>]),
    ?assertEqual(evoq_bit_flags:to_string(Status, ?GENERATION_FLAG_MAP), Label) end.

archive_bits(#{}) -> fun() ->
    ok = generation_started_v1_to_sqlite_generations:project(#{<<"division_id">> => <<"d-ab">>, <<"started_at">> => 1000}),
    ok = generation_archived_v1_to_sqlite_generations:project(#{<<"division_id">> => <<"d-ab">>}),
    {ok, [{S}]} = query_generations_store:query("SELECT status FROM generations WHERE division_id = ?1", [<<"d-ab">>]),
    ?assertEqual(?GENERATION_INITIATED bor ?GENERATION_ACTIVE bor ?GENERATION_ARCHIVED, S) end.

mod_fields(#{}) -> fun() ->
    ok = module_generated_v1_to_sqlite_generated_modules:project(
        #{<<"module_id">> => <<"m-af">>, <<"division_id">> => <<"d-af">>, <<"module_name">> => <<"user_handler">>,
          <<"module_type">> => <<"handler">>, <<"file_path">> => <<"/src/uh.erl">>, <<"content">> => <<"-module(uh).">>,
          <<"description">> => <<"desc">>, <<"generated_by">> => <<"gen">>, <<"generated_at">> => 9000}),
    {ok, [{MId, DId, Name, Type, Path, Content, Desc, By, At}]} = query_generations_store:query(
        "SELECT module_id, division_id, module_name, module_type, file_path, content, description, generated_by, generated_at "
        "FROM generated_modules WHERE module_id = ?1", [<<"m-af">>]),
    ?assertEqual(<<"m-af">>, MId), ?assertEqual(<<"d-af">>, DId), ?assertEqual(<<"user_handler">>, Name),
    ?assertEqual(<<"handler">>, Type), ?assertEqual(<<"/src/uh.erl">>, Path),
    ?assertEqual(<<"-module(uh).">>, Content), ?assertEqual(<<"desc">>, Desc),
    ?assertEqual(<<"gen">>, By), ?assertEqual(9000, At) end.
