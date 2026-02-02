%%% @doc Listener: Remote identities discovery
%%%
%%% Subscribes to identity.registered and identity.updated mesh facts.
%%% Projects directly to remote_identities table (read-only cache).
%%% No filtering needed - we cache ALL discovered identities for lookup/verification.
-module(remote_identities_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    sub_registered :: reference() | undefined,
    sub_updated :: reference() | undefined
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
    SubReg = subscribe_to_topic(<<"hecate.identity.registered">>),
    SubUpd = subscribe_to_topic(<<"hecate.identity.updated">>),
    {noreply, State#state{sub_registered = SubReg, sub_updated = SubUpd}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_registered = SubR, sub_updated = SubU}) ->
    unsubscribe(SubR),
    unsubscribe(SubU),
    ok.

%% Internal

subscribe_to_topic(Topic) ->
    Callback = fun(EventData) -> handle_fact(Topic, EventData) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[remote_identities_listener] Subscribed to ~s", [Topic]),
            SubRef;
        {error, Reason} ->
            logger:warning("[remote_identities_listener] Failed to subscribe to ~s: ~p", [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(SubRef) -> hecate_mesh_client:unsubscribe(SubRef).

handle_fact(<<"hecate.identity.registered">>, EventData) ->
    project_identity(EventData, registered);
handle_fact(<<"hecate.identity.updated">>, EventData) ->
    project_identity(EventData, updated).

%% Project to remote_identities table
project_identity(EventData, Type) ->
    try
        #{
            <<"mri">> := Mri,
            <<"public_key">> := PublicKey,
            <<"key_type">> := KeyType,
            <<"registered_at">> := RegisteredAt
        } = EventData,

        Metadata = maps:get(<<"metadata">>, EventData, #{}),
        UpdatedAt = maps:get(<<"updated_at">>, EventData, null),
        Now = erlang:system_time(second),

        Sql = case Type of
            registered ->
                "INSERT INTO remote_identities
                    (mri, public_key, key_type, metadata, registered_at, updated_at, discovered_at, last_seen_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(mri) DO UPDATE SET
                    public_key = excluded.public_key,
                    key_type = excluded.key_type,
                    metadata = excluded.metadata,
                    last_seen_at = excluded.last_seen_at";
            updated ->
                "INSERT INTO remote_identities
                    (mri, public_key, key_type, metadata, registered_at, updated_at, discovered_at, last_seen_at)
                VALUES (?, ?, ?, ?, ?, ?, ?, ?)
                ON CONFLICT(mri) DO UPDATE SET
                    public_key = excluded.public_key,
                    key_type = excluded.key_type,
                    metadata = excluded.metadata,
                    updated_at = excluded.updated_at,
                    last_seen_at = excluded.last_seen_at"
        end,

        MetadataJson = json:encode(Metadata),

        query_identities_store:execute(Sql, [
            Mri, PublicKey, KeyType, MetadataJson, RegisteredAt, UpdatedAt, Now, Now
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[remote_identities_listener] Projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
