%%% @doc Projection: mesh_fact_published_v1 -> mesh_activity ETS.
%%%
%%% Subscribes to `mesh_publications_store'. Translates each domain
%%% event into a `mesh_activity' row tagged `mesh_fact_published'.
%%% @end
-module(mesh_fact_published_v1_to_mesh_activity).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"mesh_fact_published_v1">>].

init(_Config) ->
    %% No read_model state used — we write through the store gen_server's
    %% public ETS table. Returning a placeholder satisfies the behaviour.
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => mesh_activity}),
    {ok, #{}, RM}.

project(Event, _Metadata, State, RM) ->
    Data = gf(data, Event, #{}),
    Topic = gf(topic, Data),
    Fact  = gf(fact, Data, #{}),
    TsMs  = gf(requested_at, Data, erlang:system_time(millisecond)),
    FactId = synth_fact_id(Event),
    project_mesh_activity_store:record(#{
        fact_id => FactId,
        kind    => <<"mesh_fact_published">>,
        ts_ms   => TsMs,
        payload => #{topic => Topic, fact => Fact}
    }),
    {ok, State, RM}.

%% --- helpers ---

gf(Key, Map) -> hecate_api_utils:get_field(Key, Map).
gf(Key, Map, Default) -> hecate_api_utils:get_field(Key, Map, Default).

synth_fact_id(Event) ->
    Stream  = gf(stream_id, Event, <<"mesh_publications">>),
    Version = gf(version, Event, 0),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
