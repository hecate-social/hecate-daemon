%%% @doc Mesh listener: Remote identities discovery.
%%%
%%% Subscribes to hecate.identity.registered and hecate.identity.updated
%%% mesh facts. Projects to remote_identities table in the node lifecycle
%%% read model.
-module(remote_identities_listener).
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
    [<<"hecate.identity.registered">>, <<"hecate.identity.updated">>].

subscribe_to_topic(Topic) ->
    Callback = fun(Data) -> handle_fact(Topic, Data) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[remote_identities_listener] Subscribed to ~s", [Topic]),
            Ref;
        {error, Reason} ->
            logger:warning("[remote_identities_listener] Failed to subscribe to ~s: ~p",
                          [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(Ref) -> hecate_mesh_client:unsubscribe(Ref).

handle_fact(Topic, Data) ->
    project(Topic, Data).

project(_Topic, Data) ->
    try
        #{
            <<"mri">> := Mri,
            <<"public_key">> := PublicKey,
            <<"key_type">> := KeyType
        } = Data,

        Metadata = maps:get(<<"metadata">>, Data, #{}),
        RegisteredAt = maps:get(<<"registered_at">>, Data, null),
        UpdatedAt = maps:get(<<"updated_at">>, Data, null),
        Now = erlang:system_time(millisecond),

        MetadataJson = json:encode(Metadata),

        Sql = "INSERT INTO remote_identities
                   (mri, public_key, key_type, metadata, registered_at, updated_at, discovered_at, last_seen_at)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?)
               ON CONFLICT(mri) DO UPDATE SET
                   public_key = excluded.public_key,
                   key_type = excluded.key_type,
                   metadata = excluded.metadata,
                   updated_at = excluded.updated_at,
                   last_seen_at = excluded.last_seen_at",

        query_node_lifecycle_store:execute(Sql, [
            Mri, PublicKey, KeyType, MetadataJson, RegisteredAt, UpdatedAt, Now, Now
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[remote_identities_listener] Projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
