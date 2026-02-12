%%% @doc Mesh listener: Remote capabilities discovery.
%%%
%%% Subscribes to hecate.capability.announced and hecate.capability.retracted
%%% mesh facts. Projects to remote_capabilities table in the node lifecycle
%%% read model.
-module(remote_capabilities_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {subscriptions :: [reference() | undefined]}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Callbacks

init([]) ->
    self() ! subscribe,
    {ok, #state{subscriptions = []}}.

handle_call(_Req, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    Subs = [subscribe_to_topic(T) || T <- topics()],
    {noreply, State#state{subscriptions = Subs}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscriptions = Subs}) ->
    [unsubscribe(S) || S <- Subs],
    ok.

%% Internal

topics() ->
    [<<"hecate.capability.announced">>, <<"hecate.capability.retracted">>].

subscribe_to_topic(Topic) ->
    Callback = fun(Data) -> handle_fact(Topic, Data) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[remote_capabilities_listener] Subscribed to ~s", [Topic]),
            Ref;
        {error, Reason} ->
            logger:warning("[remote_capabilities_listener] Failed to subscribe to ~s: ~p",
                          [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(Ref) -> hecate_mesh_client:unsubscribe(Ref).

handle_fact(Topic, Data) ->
    project(Topic, Data).

project(<<"hecate.capability.announced">>, Data) ->
    project_announced(Data);
project(<<"hecate.capability.retracted">>, Data) ->
    project_retracted(Data).

project_announced(Data) ->
    try
        #{
            <<"capability_mri">> := Mri,
            <<"agent_identity">> := AgentId,
            <<"announced_at">> := AnnouncedAt
        } = Data,

        Tags = maps:get(<<"tags">>, Data, []),
        Description = maps:get(<<"description">>, Data, null),
        DemoProcedure = maps:get(<<"demo_procedure">>, Data, null),
        Metadata = maps:get(<<"metadata">>, Data, #{}),
        Now = erlang:system_time(millisecond),

        TagsJson = json:encode(Tags),
        MetadataJson = json:encode(Metadata),

        Sql = "INSERT INTO remote_capabilities
                   (mri, agent_id, tags, description, demo_procedure, metadata, announced_at, discovered_at, last_seen_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(mri) DO UPDATE SET
                   agent_id = excluded.agent_id,
                   tags = excluded.tags,
                   description = excluded.description,
                   demo_procedure = excluded.demo_procedure,
                   metadata = excluded.metadata,
                   announced_at = excluded.announced_at,
                   last_seen_at = excluded.last_seen_at",

        query_node_lifecycle_store:execute(Sql, [
            Mri, AgentId, TagsJson, Description, DemoProcedure, MetadataJson,
            AnnouncedAt, Now, Now
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[remote_capabilities_listener] Announced projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.

project_retracted(Data) ->
    try
        #{<<"capability_mri">> := Mri} = Data,

        Sql = "DELETE FROM remote_capabilities WHERE mri = ?",
        query_node_lifecycle_store:execute(Sql, [Mri])
    catch
        Class:Reason:Stack ->
            logger:error("[remote_capabilities_listener] Retracted projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
