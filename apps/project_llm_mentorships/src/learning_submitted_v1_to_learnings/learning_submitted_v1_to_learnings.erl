%%% @doc Projection: learning_submitted_v1 -> learnings ETS read model.
%%% Inserts a new learning record.
-module(learning_submitted_v1_to_learnings).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, learnings).

interested_in() -> [<<"learning_submitted_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data}, _Metadata, State, RM) ->
    #{learning_id := LId, submitter_id := SId,
      category := Cat, domain := Dom, title := Title} = Data,
    Learning = #{
        id                => LId,
        submitter_id      => SId,
        category          => Cat,
        domain            => Dom,
        tags              => maps:get(tags, Data, []),
        title             => Title,
        description       => maps:get(description, Data, undefined),
        bad_example       => maps:get(bad_example, Data, undefined),
        good_example      => maps:get(good_example, Data, undefined),
        context           => maps:get(context, Data, undefined),
        severity          => maps:get(severity, Data, <<"suggestion">>),
        confidence        => maps:get(confidence, Data, 0.5),
        source            => maps:get(source, Data, <<"discovered">>),
        status            => 1,
        validator_id      => undefined,
        endorsement_count => 0,
        dispute_count     => 0,
        submitted_at      => maps:get(submitted_at, Data, erlang:system_time(millisecond)),
        validated_at      => undefined
    },
    {ok, RM2} = evoq_read_model:put(LId, Learning, RM),
    {ok, State, RM2}.
