%%% @doc Process Manager: on site node announced, admit node.
%%%
%%% Subscribes to {realm}.hecate.site.node_joined on the Macula mesh.
%%% When a remote node announces itself with the same site_id,
%%% dispatches admit_node_v1 to add it to our local site aggregate.
%%% @end
-module(on_site_node_announced_admit_node).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(RETRY_INTERVAL, 5_000).

-record(state, {
    sub_ref :: reference() | undefined
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    erlang:send_after(?RETRY_INTERVAL, self(), subscribe),
    {ok, #state{sub_ref = undefined}}.

handle_call(_Request, _From, State) ->
    {reply, ok, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, #state{sub_ref = undefined} = State) ->
    Realm = application:get_env(hecate, realm, <<"io.macula">>),
    Topic = <<Realm/binary, ".hecate.site.node_joined">>,
    %% Pass self() — hecate_mesh_client sends {mesh_fact, Topic, Data} to pid
    case hecate_mesh:subscribe(Topic, self()) of
        {ok, Ref} ->
            logger:info("[site-pm] Subscribed to ~s", [Topic]),
            {noreply, State#state{sub_ref = Ref}};
        {error, _Reason} ->
            erlang:send_after(?RETRY_INTERVAL, self(), subscribe),
            {noreply, State}
    end;

handle_info(subscribe, State) ->
    {noreply, State};

handle_info({mesh_fact, _Topic, EventData}, State) ->
    Payload = maps:get(payload, EventData, maps:get(<<"payload">>, EventData, EventData)),
    handle_fact(Payload),
    {noreply, State};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{sub_ref = Ref}) when Ref =/= undefined ->
    hecate_mesh:unsubscribe(Ref);
terminate(_Reason, _State) ->
    ok.

%%% ===================================================================
%%% Fact handling
%%% ===================================================================

handle_fact(#{<<"site_id">> := RemoteSiteId, <<"node_name">> := RemoteNodeName}) ->
    handle_fact_fields(RemoteSiteId, RemoteNodeName);
handle_fact(#{site_id := RemoteSiteId, node_name := RemoteNodeName}) ->
    handle_fact_fields(RemoteSiteId, RemoteNodeName);
handle_fact(Other) ->
    logger:debug("[site-pm] Ignoring unrecognized fact: ~p", [Other]).

handle_fact_fields(RemoteSiteId, RemoteNodeName) ->
    OurSiteId = guide_site_lifecycle_app:site_id(),
    OurNodeName = atom_to_binary(node()),
    case {RemoteSiteId =:= OurSiteId, RemoteNodeName =:= OurNodeName} of
        {false, _} ->
            logger:debug("[site-pm] Ignoring node from different site: ~s", [RemoteSiteId]);
        {true, true} ->
            ok;
        {true, false} ->
            admit_remote_node(OurSiteId, RemoteNodeName)
    end.

admit_remote_node(SiteId, NodeName) ->
    Cmd = admit_node_v1:new(NodeName, erlang:system_time(millisecond)),
    case maybe_admit_node:dispatch(SiteId, Cmd) of
        {ok, _V, _Events} ->
            logger:info("[site-pm] Admitted remote node via mesh: ~s", [NodeName]);
        {error, node_already_admitted} ->
            ok;
        {error, Reason} ->
            logger:warning("[site-pm] Failed to admit ~s: ~p", [NodeName, Reason])
    end.
