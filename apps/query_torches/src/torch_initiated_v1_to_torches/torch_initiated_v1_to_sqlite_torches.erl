%%% @doc Projection: torch_initiated_v1 -> sqlite torches table
%%% Inserts/updates torch records in the SQLite read model.
-module(torch_initiated_v1_to_sqlite_torches).

-export([project/1]).

%% @doc Project torch_initiated_v1 event to torches table.
%% Inserts a new torch with status = 1 (INITIATED).
-spec project(map()) -> ok | {error, term()}.
project(#{torch_id := TorchId} = E) ->
    logger:info("[PROJECTION] ~s: projecting ~s", [?MODULE, TorchId]),
    Sql = "INSERT OR REPLACE INTO torches "
          "(torch_id, name, brief, status, repos, skills, context_map, "
          "active_cartwheel_id, initiated_at, initiated_by) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
    Result = query_torches_store:execute(Sql, [
        TorchId,
        maps:get(name, E, <<>>),
        maps:get(brief, E, undefined),
        1,  %% INITIATED
        encode_json(maps:get(repos, E, undefined)),
        encode_json(maps:get(skills, E, undefined)),
        encode_json(maps:get(context_map, E, undefined)),
        undefined,  %% No active cartwheel yet
        maps:get(initiated_at, E, erlang:system_time(millisecond)),
        maps:get(initiated_by, E, undefined)
    ]),
    logger:info("[PROJECTION] ~s: result = ~p", [?MODULE, Result]),
    Result;
project(Other) ->
    logger:warning("[PROJECTION] ~s: unexpected event ~p", [?MODULE, Other]),
    {error, {unexpected_event, Other}}.

%% Internal

-spec encode_json(term()) -> binary() | undefined.
encode_json(undefined) -> undefined;
encode_json(Term) -> json:encode(Term).
