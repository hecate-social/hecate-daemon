%%% @doc Projection: expertise_declared_v1 -> mentor_profiles ETS read model.
%%% Upserts a mentor profile with declared domains.
-module(expertise_declared_v1_to_profiles).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-define(TABLE, mentor_profiles).

interested_in() -> [<<"expertise_declared_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := #{agent_id := AId, domains := Domains} = Data}, _Metadata, State, RM) ->
    Profile = #{
        agent_id    => AId,
        domains     => Domains,
        status      => 1,
        declared_at => maps:get(declared_at, Data, erlang:system_time(millisecond))
    },
    {ok, RM2} = evoq_read_model:put(AId, Profile, RM),
    {ok, State, RM2}.
