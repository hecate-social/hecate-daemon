%%% @doc Mesh listener: Endorsements received.
%%%
%%% Subscribes to hecate.capability.endorsed and hecate.endorsement.revoked
%%% mesh facts. Projects to my_endorsements table in the node lifecycle
%%% read model.
-module(mesh_endorsement_listener).
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
    [<<"hecate.capability.endorsed">>, <<"hecate.endorsement.revoked">>].

subscribe_to_topic(Topic) ->
    Callback = fun(Data) -> handle_fact(Topic, Data) end,
    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, Ref} ->
            logger:info("[mesh_endorsement_listener] Subscribed to ~s", [Topic]),
            Ref;
        {error, Reason} ->
            logger:warning("[mesh_endorsement_listener] Failed to subscribe to ~s: ~p",
                          [Topic, Reason]),
            undefined
    end.

unsubscribe(undefined) -> ok;
unsubscribe(Ref) -> hecate_mesh_client:unsubscribe(Ref).

handle_fact(Topic, Data) ->
    project(Topic, Data).

project(<<"hecate.capability.endorsed">>, Data) ->
    project_endorsed(Data);
project(<<"hecate.endorsement.revoked">>, Data) ->
    project_revoked(Data).

project_endorsed(Data) ->
    try
        #{
            <<"endorser_identity">> := EndorserIdentity,
            <<"capability_mri">> := CapabilityMri,
            <<"endorsed_at">> := EndorsedAt
        } = Data,

        Comment = maps:get(<<"comment">>, Data, null),
        Now = erlang:system_time(millisecond),

        Sql = "INSERT OR REPLACE INTO my_endorsements
                   (endorser_identity, my_capability_mri, comment, endorsed_at, discovered_at)
               VALUES (?, ?, ?, ?, ?)",

        query_node_lifecycle_store:execute(Sql, [
            EndorserIdentity, CapabilityMri, Comment, EndorsedAt, Now
        ])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_endorsement_listener] Endorsed projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.

project_revoked(Data) ->
    try
        #{
            <<"endorser_identity">> := EndorserIdentity,
            <<"capability_mri">> := CapabilityMri
        } = Data,

        Now = erlang:system_time(millisecond),

        Sql = "UPDATE my_endorsements SET revoked_at = ?
               WHERE endorser_identity = ? AND my_capability_mri = ?",

        query_node_lifecycle_store:execute(Sql, [Now, EndorserIdentity, CapabilityMri])
    catch
        Class:Reason:Stack ->
            logger:error("[mesh_endorsement_listener] Revoked projection failed: ~p:~p~n~p",
                        [Class, Reason, Stack]),
            {error, projection_failed}
    end.
