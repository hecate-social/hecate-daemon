%%% @doc Projection: learning_dispute_resolved_v1 -> learnings ETS read model.
%%% Sets dispute-resolved flag.
-module(learning_dispute_resolved_v1_to_learnings).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, learnings).

interested_in() -> [<<"learning_dispute_resolved_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := #{learning_id := LId}}, _Metadata, State, RM) ->
    case evoq_read_model:get(LId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                status => maps:get(status, Existing) bor 32
            },
            {ok, RM2} = evoq_read_model:put(LId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.
