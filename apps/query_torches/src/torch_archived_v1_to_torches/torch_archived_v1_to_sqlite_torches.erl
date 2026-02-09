%%% @doc Projection: torch_archived_v1 -> sqlite torches table
%%% Updates torch status with ARCHIVED bit flag in the SQLite read model.
-module(torch_archived_v1_to_sqlite_torches).

-export([project/1]).

%% Bit flags matching torch_aggregate.erl
-define(ARCHIVED, 32).  %% 2^5

%% @doc Project torch_archived_v1 event to torches table.
%% Sets the ARCHIVED bit flag on the torch's status.
-spec project(map()) -> ok | {error, term()}.
project(#{torch_id := TorchId} = _E) ->
    logger:info("[PROJECTION] ~s: projecting archive for ~s", [?MODULE, TorchId]),
    %% Use bitwise OR to set the ARCHIVED flag without clearing other bits
    Sql = "UPDATE torches SET status = status | ?1 WHERE torch_id = ?2",
    Result = query_torches_store:execute(Sql, [?ARCHIVED, TorchId]),
    logger:info("[PROJECTION] ~s: result = ~p", [?MODULE, Result]),
    Result;
project(Other) ->
    logger:warning("[PROJECTION] ~s: unexpected event ~p", [?MODULE, Other]),
    {error, {unexpected_event, Other}}.
