-module(hecate_mesh_publisher).
-behaviour(gen_server).

-export([start_link/0, publish_event/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer supertype warning (returns specific binary, spec uses binary())
-dialyzer({nowarn_function, [event_type_to_topic/1]}).

-record(state, {
    realm :: binary()
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

-spec publish_event(binary(), map()) -> ok | {error, term()}.
publish_event(EventType, EventData) ->
    gen_server:call(?MODULE, {publish_event, EventType, EventData}).

%% Callbacks

init([]) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    io:format("[hecate_mesh_publisher] Initialized for realm: ~s~n", [Realm]),
    {ok, #state{realm = Realm}}.

handle_call({publish_event, EventType, EventData}, _From, State) ->
    Topic = event_type_to_topic(EventType),
    Result = hecate_mesh_client:publish(Topic, EventData),
    log_publish_result(EventType, Topic, Result),
    {reply, Result, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

log_publish_result(EventType, Topic, ok) ->
    io:format("[hecate_mesh_publisher] Published ~s to ~s~n", [EventType, Topic]);
log_publish_result(EventType, _Topic, {error, Reason}) ->
    io:format("[hecate_mesh_publisher] Failed to publish ~s: ~p~n", [EventType, Reason]).

-spec event_type_to_topic(binary()) -> binary().
event_type_to_topic(<<"capability_announced_v1">>) -> <<"hecate.capability.announced">>;
event_type_to_topic(<<"capability_revised_v1">>) -> <<"hecate.capability.revised">>;
event_type_to_topic(<<"capability_retracted_v1">>) -> <<"hecate.capability.retracted">>;
event_type_to_topic(<<"rpc_call_tracked_v1">>) -> <<"hecate.rpc.tracked">>;
event_type_to_topic(<<"dispute_flagged_v1">>) -> <<"hecate.dispute.flagged">>;
event_type_to_topic(<<"dispute_resolved_v1">>) -> <<"hecate.dispute.resolved">>;
event_type_to_topic(<<"agent_followed_v1">>) -> <<"hecate.social.followed">>;
event_type_to_topic(<<"agent_unfollowed_v1">>) -> <<"hecate.social.unfollowed">>;
event_type_to_topic(<<"capability_endorsed_v1">>) -> <<"hecate.social.endorsed">>;
event_type_to_topic(<<"endorsement_revoked_v1">>) -> <<"hecate.social.endorsement_revoked">>;
event_type_to_topic(<<"subscribed_v1">>) -> <<"hecate.subscription.subscribed">>;
event_type_to_topic(<<"unsubscribed_v1">>) -> <<"hecate.subscription.unsubscribed">>;
event_type_to_topic(<<"identity_registered_v1">>) -> <<"hecate.identity.registered">>;
event_type_to_topic(<<"identity_updated_v1">>) -> <<"hecate.identity.updated">>;
event_type_to_topic(<<"capability_granted_v1">>) -> <<"hecate.ucan.granted">>;
event_type_to_topic(<<"capability_revoked_v1">>) -> <<"hecate.ucan.revoked">>;
event_type_to_topic(EventType) -> <<"hecate.events.", EventType/binary>>.
