%%% @doc Projection: llm_removed_v1 -> llms ETS (delete row).
%%% @end
-module(llm_removed_v1_to_llms).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, llms).

interested_in() ->
    [<<"llm_removed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    ModelName = gf(model_name, Data),
    {ok, RM2} = evoq_read_model:delete(ModelName, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
