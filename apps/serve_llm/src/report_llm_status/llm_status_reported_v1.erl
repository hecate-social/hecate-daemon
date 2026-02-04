%%% @doc Event: LLM status reported
%%% Emitted periodically with current model availability and performance.
-module(llm_status_reported_v1).

-export([new/2, to_map/1, from_map/1]).
-export([model_name/1, status/1, reported_at/1]).

-record(llm_status_reported_v1, {
    model_name :: binary(),
    status :: map(),
    reported_at :: non_neg_integer()
}).

-opaque t() :: #llm_status_reported_v1{}.
-export_type([t/0]).

new(ModelName, Status) ->
    {ok, #llm_status_reported_v1{
        model_name = ModelName,
        status = Status,
        reported_at = erlang:system_time(millisecond)
    }}.

to_map(#llm_status_reported_v1{model_name = N, status = S, reported_at = R}) ->
    #{model_name => N, status => S, reported_at => R}.

from_map(#{model_name := N, status := S, reported_at := R}) ->
    {ok, #llm_status_reported_v1{model_name = N, status = S, reported_at = R}}.

model_name(#llm_status_reported_v1{model_name = V}) -> V.
status(#llm_status_reported_v1{status = V}) -> V.
reported_at(#llm_status_reported_v1{reported_at = V}) -> V.
