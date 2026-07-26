%%% @doc Projection: mesh_subscription_{added,removed}_v1 -> mesh_subscriptions ETS.
%%%
%%% Maintains the current subscription roster keyed by Topic. Added
%%% events insert (or overwrite — idempotent at the aggregate above);
%%% removed events delete. The query desk `get_mesh_subscriptions_api'
%%% reads from this table.
%%% @end
-module(mesh_subscriptions_lifecycle_to_subscription_list).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() ->
    [<<"mesh_subscription_added_v1">>,
     <<"mesh_subscription_removed_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => mesh_subscriptions}),
    {ok, #{}, RM}.

project(#{event_type := <<"mesh_subscription_added_v1">>} = Event,
        _Metadata, State, RM) ->
    Data = gf(data, Event, #{}),
    Topic = gf(topic, Data),
    SubscribedAt = gf(requested_at, Data, erlang:system_time(millisecond)),
    FactId = synth_fact_id(Event),
    case Topic of
        T when is_binary(T) ->
            project_mesh_activity_store:record_subscription(#{
                topic         => T,
                subscribed_at => SubscribedAt,
                fact_id       => FactId
            });
        _ ->
            ok
    end,
    {ok, State, RM};
project(#{event_type := <<"mesh_subscription_removed_v1">>} = Event,
        _Metadata, State, RM) ->
    Data = gf(data, Event, #{}),
    case gf(topic, Data) of
        T when is_binary(T) ->
            project_mesh_activity_store:drop_subscription(T);
        _ ->
            ok
    end,
    {ok, State, RM};
project(_Event, _Metadata, State, RM) ->
    {ok, State, RM}.

%% --- helpers ---

gf(Key, Map) -> hecate_api_utils:get_field(Key, Map).
gf(Key, Map, Default) -> hecate_api_utils:get_field(Key, Map, Default).

synth_fact_id(Event) ->
    Stream  = gf(stream_id, Event, <<"mesh_subscriptions">>),
    Version = gf(version, Event, 0),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
