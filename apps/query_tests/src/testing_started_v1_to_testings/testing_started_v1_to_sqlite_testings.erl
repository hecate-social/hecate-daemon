%%% @doc Projection: testing_started_v1 -> testings table
-module(testing_started_v1_to_sqlite_testings).

-include_lib("test_division/include/testing_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    StartedAt = get(started_at, Event),
    StartedBy = get(started_by, Event),
    Status = evoq_bit_flags:set(evoq_bit_flags:set(0, ?TESTING_INITIATED), ?TESTING_ACTIVE),
    StatusLabel = evoq_bit_flags:to_string(Status, ?TESTING_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO testings "
          "(division_id, status, status_label, started_at, started_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_tests_store:execute(Sql, [DivisionId, Status, StatusLabel, StartedAt, StartedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
