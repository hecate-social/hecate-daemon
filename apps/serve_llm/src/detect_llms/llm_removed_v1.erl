%%% @doc Event: LLM removed
-module(llm_removed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([model_name/1, removed_at/1]).

-record(llm_removed_v1, {
    model_name :: binary(),
    removed_at :: non_neg_integer()
}).

-opaque t() :: #llm_removed_v1{}.
-export_type([t/0]).

new(ModelName) ->
    {ok, #llm_removed_v1{
        model_name = ModelName,
        removed_at = erlang:system_time(millisecond)
    }}.

to_map(#llm_removed_v1{model_name = N, removed_at = R}) ->
    #{model_name => N, removed_at => R}.

from_map(#{model_name := N, removed_at := R}) ->
    {ok, #llm_removed_v1{model_name = N, removed_at = R}}.

model_name(#llm_removed_v1{model_name = V}) -> V.
removed_at(#llm_removed_v1{removed_at = V}) -> V.
