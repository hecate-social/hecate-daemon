%%%-------------------------------------------------------------------
%%% @doc Tests for hecate_store module.
%%% @end
%%%-------------------------------------------------------------------
-module(hecate_store_tests).

-include_lib("eunit/include/eunit.hrl").

%%====================================================================
%% Test Descriptions
%%====================================================================

store_test_() ->
    {foreach,
        fun setup/0,
        fun cleanup/1,
        [
            {"put and get value", fun put_get_value/0},
            {"get non-existent key returns not_found", fun get_not_found/0},
            {"put overwrites existing value", fun put_overwrite/0},
            {"delete removes value", fun delete_value/0},
            {"delete non-existent key is ok", fun delete_not_found/0},
            {"list returns all keys in bucket", fun list_bucket/0},
            {"list empty bucket returns empty list", fun list_empty_bucket/0},
            {"buckets are isolated", fun bucket_isolation/0},
            {"append and get events", fun append_get_events/0},
            {"events ordered by id descending then reversed", fun events_ordering/0},
            {"get events with limit", fun events_limit/0},
            {"complex erlang terms are preserved", fun complex_terms/0}
        ]
    }.

%%====================================================================
%% Setup / Cleanup
%%====================================================================

setup() ->
    %% Use unique temp dir per test
    TempDir = "/tmp/hecate_store_test_" ++ integer_to_list(erlang:unique_integer([positive])),
    ok = filelib:ensure_dir(filename:join(TempDir, "dummy")),
    application:set_env(hecate, data_dir, TempDir),
    
    %% Start dependencies
    
    {ok, _} = application:ensure_all_started(esqlite),
    
    %% Start store
    {ok, Pid} = hecate_store:start_link(),
    {Pid, TempDir}.

cleanup({Pid, TempDir}) ->
    gen_server:stop(Pid),
    os:cmd("rm -rf " ++ TempDir),
    ok.

%%====================================================================
%% Test Cases
%%====================================================================

put_get_value() ->
    ok = hecate_store:put(<<"test">>, <<"key1">>, <<"value1">>),
    ?assertEqual({ok, <<"value1">>}, hecate_store:get(<<"test">>, <<"key1">>)).

get_not_found() ->
    ?assertEqual(not_found, hecate_store:get(<<"test">>, <<"nonexistent">>)).

put_overwrite() ->
    ok = hecate_store:put(<<"test">>, <<"key">>, <<"original">>),
    ok = hecate_store:put(<<"test">>, <<"key">>, <<"updated">>),
    ?assertEqual({ok, <<"updated">>}, hecate_store:get(<<"test">>, <<"key">>)).

delete_value() ->
    ok = hecate_store:put(<<"test">>, <<"to_delete">>, <<"value">>),
    ?assertEqual({ok, <<"value">>}, hecate_store:get(<<"test">>, <<"to_delete">>)),
    ok = hecate_store:delete(<<"test">>, <<"to_delete">>),
    ?assertEqual(not_found, hecate_store:get(<<"test">>, <<"to_delete">>)).

delete_not_found() ->
    ?assertEqual(ok, hecate_store:delete(<<"test">>, <<"never_existed">>)).

list_bucket() ->
    ok = hecate_store:put(<<"bucket1">>, <<"a">>, 1),
    ok = hecate_store:put(<<"bucket1">>, <<"b">>, 2),
    ok = hecate_store:put(<<"bucket1">>, <<"c">>, 3),
    
    Result = hecate_store:list(<<"bucket1">>),
    ?assertEqual(3, length(Result)),
    
    %% Check all keys present
    Keys = [K || {K, _} <- Result],
    ?assert(lists:member(<<"a">>, Keys)),
    ?assert(lists:member(<<"b">>, Keys)),
    ?assert(lists:member(<<"c">>, Keys)).

list_empty_bucket() ->
    ?assertEqual([], hecate_store:list(<<"empty_bucket">>)).

bucket_isolation() ->
    ok = hecate_store:put(<<"bucket_a">>, <<"key">>, <<"value_a">>),
    ok = hecate_store:put(<<"bucket_b">>, <<"key">>, <<"value_b">>),
    
    ?assertEqual({ok, <<"value_a">>}, hecate_store:get(<<"bucket_a">>, <<"key">>)),
    ?assertEqual({ok, <<"value_b">>}, hecate_store:get(<<"bucket_b">>, <<"key">>)),
    
    %% Delete from one bucket doesn't affect other
    ok = hecate_store:delete(<<"bucket_a">>, <<"key">>),
    ?assertEqual(not_found, hecate_store:get(<<"bucket_a">>, <<"key">>)),
    ?assertEqual({ok, <<"value_b">>}, hecate_store:get(<<"bucket_b">>, <<"key">>)).

append_get_events() ->
    ok = hecate_store:append_event(<<"stream1">>, <<"type_a">>, #{data => <<"test">>}),
    ok = hecate_store:append_event(<<"stream1">>, <<"type_b">>, #{count => 42}),
    
    Events = hecate_store:get_events(<<"stream1">>, #{}),
    ?assertEqual(2, length(Events)),
    
    %% First event
    [E1, E2] = Events,
    ?assertEqual(<<"type_a">>, maps:get(type, E1)),
    ?assertEqual(#{data => <<"test">>}, maps:get(data, E1)),
    
    %% Second event
    ?assertEqual(<<"type_b">>, maps:get(type, E2)),
    ?assertEqual(#{count => 42}, maps:get(data, E2)).

events_ordering() ->
    ok = hecate_store:append_event(<<"ordered">>, <<"first">>, #{}),
    ok = hecate_store:append_event(<<"ordered">>, <<"second">>, #{}),
    ok = hecate_store:append_event(<<"ordered">>, <<"third">>, #{}),
    
    Events = hecate_store:get_events(<<"ordered">>, #{}),
    Types = [maps:get(type, E) || E <- Events],
    ?assertEqual([<<"first">>, <<"second">>, <<"third">>], Types).

events_limit() ->
    %% Add 5 events
    lists:foreach(fun(N) ->
        ok = hecate_store:append_event(<<"limited">>, <<"event">>, #{n => N})
    end, lists:seq(1, 5)),
    
    %% Get with limit 3
    Events = hecate_store:get_events(<<"limited">>, #{limit => 3}),
    ?assertEqual(3, length(Events)),
    
    %% Should be the last 3 (most recent)
    Nums = [maps:get(n, maps:get(data, E)) || E <- Events],
    ?assertEqual([3, 4, 5], Nums).

complex_terms() ->
    ComplexValue = #{
        binary => <<"hello">>,
        integer => 42,
        float => 3.14,
        list => [1, 2, 3],
        nested => #{a => #{b => #{c => <<"deep">>}}},
        tuple => {ok, done},
        atom => some_atom
    },
    
    ok = hecate_store:put(<<"complex">>, <<"key">>, ComplexValue),
    {ok, Retrieved} = hecate_store:get(<<"complex">>, <<"key">>),
    ?assertEqual(ComplexValue, Retrieved).
