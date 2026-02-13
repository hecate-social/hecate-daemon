%%% @doc Projection: vision_refined_v1 -> ventures table (set vision refined flag + update fields)
-module(vision_refined_v1_to_sqlite_ventures).

-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").

-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    Brief = get(brief, Event, undefined),
    Repos = encode_json(get(repos, Event, undefined)),
    Skills = encode_json(get(skills, Event, undefined)),
    ContextMap = encode_json(get(context_map, Event, undefined)),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, VentureId]),
    %% Set the VISION_REFINED flag and update fields (COALESCE preserves existing when null)
    ok = query_venture_lifecycle_store:execute(
        "UPDATE ventures SET status = status | ?1, "
        "brief = COALESCE(?2, brief), "
        "repos = COALESCE(?3, repos), "
        "skills = COALESCE(?4, skills), "
        "context_map = COALESCE(?5, context_map) "
        "WHERE venture_id = ?6",
        [?VL_VISION_REFINED, Brief, Repos, Skills, ContextMap, VentureId]),
    %% Recompute label
    case query_venture_lifecycle_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1", [VentureId]) of
        {ok, [[NewStatus]]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?VL_FLAG_MAP),
            query_venture_lifecycle_store:execute(
                "UPDATE ventures SET status_label = ?1 WHERE venture_id = ?2",
                [Label, VentureId]);
        _ -> ok
    end.

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
