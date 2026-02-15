%%% @doc Projection: venture_repo_scaffolded_v1 -> ventures table
%%% Sets VL_VISION_REFINED (2) and VL_SUBMITTED (4) flags, updates repo_path and brief.
-module(venture_repo_scaffolded_v1_to_sqlite_ventures).

-include_lib("guide_venture_lifecycle/include/venture_lifecycle_status.hrl").

-export([project/1]).

project(Event) ->
    VentureId = get(venture_id, Event),
    Brief = get(brief, Event),
    RepoPath = get(repo_path, Event),
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, VentureId]),
    Status = ?VL_VISION_REFINED bor ?VL_SUBMITTED,
    StatusLabel = <<"Vision Submitted">>,
    Sql = "UPDATE ventures "
          "SET brief = COALESCE(?1, brief), "
          "repo_path = ?2, "
          "status = status | ?3, "
          "status_label = ?4 "
          "WHERE venture_id = ?5",
    query_venture_lifecycle_store:execute(Sql, [
        Brief, RepoPath, Status, StatusLabel, VentureId
    ]).

get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
