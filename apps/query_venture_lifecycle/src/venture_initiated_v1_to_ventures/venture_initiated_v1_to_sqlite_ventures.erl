%%% @doc Projection: venture_initiated_v1 -> ventures table
-module(venture_initiated_v1_to_sqlite_ventures).

-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").

-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    Name = get(name, Event),
    Brief = get(brief, Event),
    Repos = encode_json(get(repos, Event, [])),
    Skills = encode_json(get(skills, Event, [])),
    ContextMap = encode_json(get(context_map, Event, #{})),
    InitiatedAt = get(initiated_at, Event),
    InitiatedBy = get(initiated_by, Event),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, VentureId]),
    Status = evoq_bit_flags:set(0, ?VL_INITIATED),
    StatusLabel = evoq_bit_flags:to_string(Status, ?VL_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO ventures "
          "(venture_id, name, brief, status, status_label, repos, skills, "
          "context_map, initiated_at, initiated_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
    query_venture_lifecycle_store:execute(Sql, [
        VentureId, Name, Brief, Status, StatusLabel,
        Repos, Skills, ContextMap, InitiatedAt, InitiatedBy
    ]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.

encode_json(null) -> null;
encode_json(undefined) -> null;
encode_json(Val) -> json:encode(Val).
