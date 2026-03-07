%%% @doc Projection: expertise_withdrawn_v1 -> mentor_profiles ETS read model.
%%% Sets withdrawn flag on existing profile.
-module(expertise_withdrawn_v1_to_profiles).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, mentor_profiles).

interested_in() -> [<<"expertise_withdrawn_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := #{agent_id := AId}}, _Metadata, State, RM) ->
    case evoq_read_model:get(AId, RM) of
        {ok, Existing} ->
            Updated = Existing#{status => maps:get(status, Existing) bor 2},
            {ok, RM2} = evoq_read_model:put(AId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.
