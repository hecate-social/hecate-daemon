%%% @doc Projection: testing_archived_v1 -> testings table (set archived flag)
-module(testing_archived_v1_to_sqlite_testings).

-include_lib("test_division/include/testing_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    %% Set the ARCHIVED flag
    ok = query_tests_store:execute(
        "UPDATE testings SET status = status | ?1 WHERE division_id = ?2",
        [?TESTING_ARCHIVED, DivisionId]),
    %% Recompute label
    case query_tests_store:query(
        "SELECT status FROM testings WHERE division_id = ?1", [DivisionId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?TESTING_FLAG_MAP),
            query_tests_store:execute(
                "UPDATE testings SET status_label = ?1 WHERE division_id = ?2",
                [Label, DivisionId]);
        _ -> ok
    end.

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
