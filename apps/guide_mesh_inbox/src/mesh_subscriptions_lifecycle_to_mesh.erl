%%% @doc Bridge: mesh_subscriptions_store events -> hecate_mesh.
%%%
%%% Subscribes to the two domain events produced by
%%% `guide_mesh_subscriptions':
%%%
%%%   * `mesh_subscription_added_v1' — calls
%%%     `hecate_mesh:subscribe(Topic, fun receive_mesh_fact_listener:on_fact/3)'
%%%     and stores the returned SubRef under the topic.
%%%   * `mesh_subscription_removed_v1' — looks up the SubRef and calls
%%%     `hecate_mesh:unsubscribe/1', then drops the entry.
%%%
%%% Survives daemon restart by replay: on boot, evoq re-feeds the
%%% subscription stream and we re-install every active subscription.
%%% Idempotent at the aggregate boundary above us, so no duplicate-add /
%%% double-unsubscribe storms.
%%%
%%% Handles inbound subscribe calls even when `hecate_mesh' isn't
%%% activated yet; the mesh layer queues pending subscriptions and
%%% drains them once a station connects.
%%% @end
-module(mesh_subscriptions_lifecycle_to_mesh).
-behaviour(evoq_event_handler).

-export([interested_in/0, init/1, handle_event/4]).

interested_in() ->
    [<<"mesh_subscription_added_v1">>,
     <<"mesh_subscription_removed_v1">>].

init(_Config) ->
    {ok, #{topics => #{}}}.

handle_event(<<"mesh_subscription_added_v1">>,
             #{data := #{topic := Topic}}, _Metadata,
             #{topics := Topics} = State) when is_binary(Topic) ->
    handle_added(Topic, Topics, State);
handle_event(<<"mesh_subscription_added_v1">>,
             #{topic := Topic}, _Metadata,
             #{topics := Topics} = State) when is_binary(Topic) ->
    handle_added(Topic, Topics, State);

handle_event(<<"mesh_subscription_removed_v1">>,
             #{data := #{topic := Topic}}, _Metadata,
             #{topics := Topics} = State) when is_binary(Topic) ->
    handle_removed(Topic, Topics, State);
handle_event(<<"mesh_subscription_removed_v1">>,
             #{topic := Topic}, _Metadata,
             #{topics := Topics} = State) when is_binary(Topic) ->
    handle_removed(Topic, Topics, State);

handle_event(_EventType, Data, _Metadata, State) ->
    logger:warning("[mesh_subscriptions_lifecycle_to_mesh] dropping malformed event: ~p",
                   [Data]),
    {ok, State}.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

handle_added(Topic, Topics, State) ->
    case maps:get(Topic, Topics, undefined) of
        SubRef when SubRef =/= undefined ->
            %% Already wired (re-event during boot replay or duplicate).
            {ok, State};
        undefined ->
            Callback = fun receive_mesh_fact_listener:on_fact/3,
            case hecate_mesh:subscribe(Topic, Callback) of
                {ok, SubRef} ->
                    {ok, State#{topics => Topics#{Topic => SubRef}}};
                {error, Reason} ->
                    logger:warning("[mesh_subscriptions_lifecycle_to_mesh] subscribe ~s failed: ~p",
                                   [Topic, Reason]),
                    {ok, State}
            end
    end.

handle_removed(Topic, Topics, State) ->
    case maps:get(Topic, Topics, undefined) of
        undefined ->
            {ok, State};
        SubRef ->
            case hecate_mesh:unsubscribe(SubRef) of
                ok ->
                    ok;
                {error, Reason} ->
                    logger:warning("[mesh_subscriptions_lifecycle_to_mesh] unsubscribe ~s failed: ~p",
                                   [Topic, Reason])
            end,
            {ok, State#{topics => maps:remove(Topic, Topics)}}
    end.
