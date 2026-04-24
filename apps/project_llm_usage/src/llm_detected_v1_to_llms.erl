%%% @doc Projection: llm_detected_v1 -> llms ETS.
%%%
%%% Keyed by model_name. Overwrites on re-detection so the read model
%%% reflects the latest known metadata. Pair with
%%% `llm_removed_v1_to_llms` which deletes the row on removal.
%%% @end
-module(llm_detected_v1_to_llms).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, llms).

interested_in() ->
    [<<"llm_detected_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    ModelName = gf(model_name, Data),
    Entry = #{
        model_name  => ModelName,
        model_info  => gf(model_info, Data),
        detected_at => gf(detected_at, Data)
    },
    {ok, RM2} = evoq_read_model:put(ModelName, Entry, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
