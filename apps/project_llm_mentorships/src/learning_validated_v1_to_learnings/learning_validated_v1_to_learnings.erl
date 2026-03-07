%%% @doc Projection: learning_validated_v1 -> learnings ETS read model.
%%% Sets validated status and validator on existing learning.
-module(learning_validated_v1_to_learnings).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, learnings).

interested_in() -> [<<"learning_validated_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := #{learning_id := LId, validator_id := VId} = Data}, _Metadata, State, RM) ->
    case evoq_read_model:get(LId, RM) of
        {ok, Existing} ->
            Updated = Existing#{
                status       => maps:get(status, Existing) bor 2,
                validator_id => VId,
                validated_at => maps:get(validated_at, Data, erlang:system_time(millisecond))
            },
            {ok, RM2} = evoq_read_model:put(LId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.
