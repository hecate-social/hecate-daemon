%%% @doc Listener: Remote capabilities discovery
%%%
%%% Subscribes to capability.announced and capability.revised mesh facts.
%%% Projects directly to remote_capabilities table (read-only cache).
%%% No filtering needed - we cache ALL discovered capabilities for discovery queries.
-module(remote_capabilities_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_announced :: reference() | undefined,
    sub_revised :: reference() | undefined
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Callbacks

init([]) ->
    self() ! subscribe,
    {ok, #state{}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    SubAnnounced = subscribe_to_topic(<<"hecate.capability.announced">>),
    SubRevised = subscribe_to_topic(<<"hecate.capability.revised">>),
    {noreply, State#state{sub_announced = SubAnnounced, sub_revised = SubRevised}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_announced = SubA, sub_revised = SubR}) ->
    unsubscribe(SubA),
    unsubscribe(SubR),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[remote_capabilities_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[remote_capabilities_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.capability.announced">>, EventData) ->
    project_capability(EventData);
handle_fact(<<"hecate.capability.revised">>, EventData) ->
    project_capability(EventData).

%% Project to remote_capabilities table
project_capability(EventData) ->
    try
        #{
            <<"mri">> := Mri,
            <<"agent_id">> := AgentId,
            <<"tags">> := Tags,
            <<"description">> := Description,
            <<"announced_at">> := AnnouncedAt
        } = EventData,

        DemoProcedure = maps:get(<<"demo_procedure">>, EventData, null),
        Metadata = maps:get(<<"metadata">>, EventData, #{}),
        Now = erlang:system_time(second),

        Sql = "
            INSERT INTO remote_capabilities
                (mri, agent_id, tags, description, demo_procedure, metadata, announced_at, discovered_at, last_seen_at)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
            ON CONFLICT(mri) DO UPDATE SET
                agent_id = excluded.agent_id,
                tags = excluded.tags,
                description = excluded.description,
                demo_procedure = excluded.demo_procedure,
                metadata = excluded.metadata,
                announced_at = excluded.announced_at,
                last_seen_at = excluded.last_seen_at
        ",

        TagsJson = json:encode(Tags),
        MetadataJson = json:encode(Metadata),

        query_capabilities_store:execute(Sql, [
            Mri, AgentId, TagsJson, Description, DemoProcedure, MetadataJson,
            AnnouncedAt, Now, Now
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[remote_capabilities_listener] Projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
