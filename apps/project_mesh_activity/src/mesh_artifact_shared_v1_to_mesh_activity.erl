%%% @doc Projection: mesh_artifact_shared_v1 -> mesh_activity ETS.
%%%
%%% Subscribes to `mesh_artifacts_store'. Translates each domain event
%%% into a `mesh_activity' row tagged `mesh_artifact_shared'.
%%% @end
-module(mesh_artifact_shared_v1_to_mesh_activity).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

interested_in() -> [<<"mesh_artifact_shared_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => mesh_activity}),
    {ok, #{}, RM}.

project(Event, _Metadata, State, RM) ->
    Data = gf(data, Event, #{}),
    MCID        = gf(mcid, Data),
    ContentType = gf(content_type, Data, <<"application/octet-stream">>),
    SizeBytes   = gf(size_bytes, Data, 0),
    TsMs        = gf(shared_at, Data, erlang:system_time(millisecond)),
    FactId      = synth_fact_id(Event),
    project_mesh_activity_store:record(#{
        fact_id => FactId,
        kind    => <<"mesh_artifact_shared">>,
        ts_ms   => TsMs,
        payload => #{
            mcid_hex     => to_hex(MCID),
            content_type => ContentType,
            size_bytes   => SizeBytes
        }
    }),
    {ok, State, RM}.

%% --- helpers ---

gf(Key, Map) -> hecate_api_utils:get_field(Key, Map).
gf(Key, Map, Default) -> hecate_api_utils:get_field(Key, Map, Default).

synth_fact_id(Event) ->
    Stream  = gf(stream_id, Event, <<"mesh_artifacts">>),
    Version = gf(version, Event, 0),
    iolist_to_binary([Stream, <<"@">>, integer_to_binary(Version)]).

to_hex(undefined) -> <<>>;
to_hex(<<>>) -> <<>>;
to_hex(Bin) when is_binary(Bin) ->
    list_to_binary(lists:flatten(
        [io_lib:format("~2.16.0b", [B]) || <<B>> <= Bin])).
