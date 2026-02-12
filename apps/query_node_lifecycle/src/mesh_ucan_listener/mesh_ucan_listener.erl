%%% @doc Mesh listener: UCAN grants received.
%%%
%%% Subscribes to hecate.ucan.granted and hecate.ucan.revoked
%%% mesh facts. Projects to received_ucans table in the node lifecycle
%%% read model.
-module(mesh_ucan_listener).
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
    [<<"hecate.ucan.granted">>, <<"hecate.ucan.revoked">>].

subscribe_to_topic(Topic) ->
    Callback = fun(Data) -> handle_fact(Topic, Data) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[mesh_ucan_listener] Subscribed to ~s", [Topic]),
            Ref;
        {error, Reason} ->
            logger:warning("[mesh_ucan_listener] Failed to subscribe to ~s: ~p",
                          [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(Ref) -> hecate_mesh_client:unsubscribe(Ref).

handle_fact(Topic, Data) ->
    project(Topic, Data).

project(<<"hecate.ucan.granted">>, Data) ->
    project_granted(Data);
project(<<"hecate.ucan.revoked">>, Data) ->
    project_revoked(Data).

project_granted(Data) ->
    try
        #{
            <<"capability_id">> := CapabilityId,
            <<"issuer">> := Issuer,
            <<"audience">> := MyIdentity,
            <<"resource">> := Resource,
            <<"actions">> := Actions,
            <<"expires_at">> := ExpiresAt,
            <<"granted_at">> := GrantedAt
        } = Data,

        TokenCid = maps:get(<<"token_cid">>, Data, null),
        Now = erlang:system_time(millisecond),
        ActionsJson = json:encode(Actions),

        Sql = "INSERT OR REPLACE INTO received_ucans
                   (capability_id, issuer, my_identity, resource, actions, expires_at, granted_at, discovered_at, token_cid)
               VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)",

        query_node_lifecycle_store:execute(Sql, [
            CapabilityId, Issuer, MyIdentity, Resource, ActionsJson,
            ExpiresAt, GrantedAt, Now, TokenCid
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_ucan_listener] Granted projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.

project_revoked(Data) ->
    try
        #{<<"capability_id">> := CapabilityId} = Data,

        Now = erlang:system_time(millisecond),

        Sql = "UPDATE received_ucans SET revoked = 1, revoked_at = ?
               WHERE capability_id = ?",

        query_node_lifecycle_store:execute(Sql, [Now, CapabilityId])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_ucan_listener] Revoked projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
