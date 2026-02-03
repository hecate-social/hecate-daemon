%%% @doc Projection: llm_capability_retracted_v1 → capabilities table
%%% Removes LLM capabilities from the read model when retracted.
-module(llm_capability_retracted_v1_to_capabilities).

-export([project/1]).

%% @doc Project llm_capability_retracted_v1 event to capabilities table
-spec project(map()) -> ok | {error, term()}.
project(EventData) when is_map(EventData) ->
    MRI = maps:get(capability_mri, EventData, <<>>),

    %% Delete from capabilities table
    Sql = "DELETE FROM capabilities WHERE mri = ?",
    Params = [MRI],

    case query_capabilities_store:execute(Sql, Params) of
        ok ->
            logger:debug("[llm_projection] Retracted LLM capability: ~s", [MRI]),
            ok;
        {error, Reason} ->
            logger:warning("[llm_projection] Failed to retract: ~p", [Reason]),
            {error, Reason}
    end.
