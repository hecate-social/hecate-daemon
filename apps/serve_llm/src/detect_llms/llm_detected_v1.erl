%%% @doc Event: LLM detected
-module(llm_detected_v1).

-export([new/2, to_map/1, from_map/1]).
-export([model_name/1, model_info/1, detected_at/1]).

-record(llm_detected_v1, {
    model_name :: binary(),
    model_info :: map(),
    detected_at :: non_neg_integer()
}).

-opaque t() :: #llm_detected_v1{}.
-export_type([t/0]).

new(ModelName, ModelInfo) ->
    {ok, #llm_detected_v1{
        model_name = ModelName,
        model_info = ModelInfo,
        detected_at = erlang:system_time(millisecond)
    }}.

to_map(#llm_detected_v1{model_name = N, model_info = I, detected_at = D}) ->
    #{model_name => N, model_info => I, detected_at => D}.

from_map(#{model_name := N, model_info := I, detected_at := D}) ->
    {ok, #llm_detected_v1{model_name = N, model_info = I, detected_at = D}}.

model_name(#llm_detected_v1{model_name = V}) -> V.
model_info(#llm_detected_v1{model_info = V}) -> V.
detected_at(#llm_detected_v1{detected_at = V}) -> V.
