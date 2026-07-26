%%% @doc Projection: mesh_fact_received_v1 -> mesh_activity ETS.
%%%
%%% Subscribes to `mesh_inbox_store'. Translates each domain event
%%% into a `mesh_activity' row tagged `mesh_fact_received', with a
%%% `direction => in' marker in the payload so query consumers can
%%% filter inbound vs outbound activity through one unified table.
%%% @end
-module(mesh_fact_received_v1_to_mesh_activity).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"mesh_fact_received_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => mesh_activity}),
    {ok, #{}, RM}.

project(Event, _Metadata, State, RM) ->
    Data         = gf(data, Event, #{}),
    Topic        = gf(topic, Data),
    Fact         = gf(fact, Data, #{}),
    SenderNodeId = gf(sender_node_id, Data, undefined),
    SenderMri    = gf(sender_mri, Data, undefined),
    SigVerified  = gf(sig_verified, Data, false),
    TsMs         = gf(received_at, Data, erlang:system_time(millisecond)),
    FactId       = synth_fact_id(Event),
    project_mesh_activity_store:record(#{
        fact_id => FactId,
        kind    => <<"mesh_fact_received">>,
        ts_ms   => TsMs,
        payload => #{
            direction      => <<"in">>,
            topic          => Topic,
            fact           => Fact,
            sender_node_id => SenderNodeId,
            sender_mri     => SenderMri,
            sig_verified   => SigVerified
        }
    }),
    {ok, State, RM}.

%% --- helpers ---

gf(Key, Map) -> hecate_api_utils:get_field(Key, Map).
gf(Key, Map, Default) -> hecate_api_utils:get_field(Key, Map, Default).

synth_fact_id(Event) ->
    Stream  = gf(stream_id, Event, <<"mesh_inbox">>),
    Version = gf(version, Event, 0),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).
