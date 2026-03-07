%%% @doc Projection: llm_call_tracked_v1 -> llm_calls ETS.
%%% @end
-module(llm_call_tracked_v1_to_llm_calls).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, llm_calls).

interested_in() ->
    [<<"llm_call_tracked_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    CallId = gf(call_id, Data),
    Entry = #{
        call_id     => CallId,
        venture_id  => gf(venture_id, Data),
        division_id => gf(division_id, Data),
        agent_id    => gf(agent_id, Data),
        task_id     => gf(task_id, Data),
        model       => gf(model, Data),
        tokens_in   => gf(tokens_in, Data),
        tokens_out  => gf(tokens_out, Data),
        cost_usd    => gf(cost_usd, Data),
        tracked_at  => gf(tracked_at, Data)
    },
    {ok, RM2} = evoq_read_model:put(CallId, Entry, RM),
    {ok, State, RM2}.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
