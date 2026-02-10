%%% @doc Projection: plan_started_v1 -> plans table
-module(plan_started_v1_to_sqlite_plans).

-include_lib("plan_division/include/plan_status.hrl").

-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    StartedAt = get(started_at, Event),
    StartedBy = get(started_by, Event),
    Status = evoq_bit_flags:set(evoq_bit_flags:set(0, ?PLAN_INITIATED), ?PLAN_ACTIVE),
    StatusLabel = evoq_bit_flags:to_string(Status, ?PLAN_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO plans "
          "(division_id, status, status_label, started_at, started_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5)",
    query_plans_store:execute(Sql, [DivisionId, Status, StatusLabel, StartedAt, StartedBy]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
