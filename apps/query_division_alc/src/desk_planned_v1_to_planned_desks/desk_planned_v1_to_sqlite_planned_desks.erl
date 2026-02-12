%%% @doc Projection: desk_planned_v1 -> planned_desks table
-module(desk_planned_v1_to_sqlite_planned_desks).
-export([project/1]).

project(Event) ->
    DivisionId = get(division_id, Event),
    DeskName = get(desk_name, Event),
    Description = get(description, Event),
    Department = get(department, Event),
    Commands = encode_json(get(commands, Event)),
    PlannedAt = get(planned_at, Event),
    logger:info("[PROJECTION] ~s: projecting ~s/~s", [?MODULE, DivisionId, DeskName]),
    Sql = "INSERT OR REPLACE INTO planned_desks "
          "(division_id, desk_name, description, department, "
          "commands, planned_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6)",
    query_division_alc_store:execute(Sql, [DivisionId, DeskName, Description,
                                           Department, Commands, PlannedAt]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

encode_json(undefined) -> undefined;
encode_json(null) -> undefined;
encode_json(Value) when is_list(Value); is_map(Value) ->
    iolist_to_binary(json:encode(Value));
encode_json(Value) when is_binary(Value) -> Value.
