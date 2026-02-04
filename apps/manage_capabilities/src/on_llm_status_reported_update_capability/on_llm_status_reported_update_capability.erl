%%% @doc Process Manager: On LLM Status Reported, Update Capability
%%% Subscribes to llm_status_reported_v1 events from serve_llm domain.
%%% Dispatches update_capability_v1 commands to manage_capabilities
%%% with updated status metadata (queue_depth, availability, performance).
-module(on_llm_status_reported_update_capability).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [subscribe_to_status_events/0]}).

-record(state, {
    subscription_ref :: reference() | undefined,
    agent_identity :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    AgentIdentity = get_agent_identity(),
    self() ! subscribe,
    {ok, #state{subscription_ref = undefined, agent_identity = AgentIdentity}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    SubRef = subscribe_to_status_events(),
    {noreply, State#state{subscription_ref = SubRef}};
handle_info({event, EventType, EventData}, #state{agent_identity = AgentId} = State) ->
    handle_event(EventType, EventData, AgentId),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

subscribe_to_status_events() ->
    Self = self(),
    Callback = fun(EventType, EventData, _Metadata) ->
        Self ! {event, EventType, EventData}
    end,
    case reckon_evoq_adapter:subscribe(serve_llm_store, <<"llm_status">>, Callback) of
        {ok, SubRef} -> SubRef;
        {error, _} -> undefined
    end.

handle_event(<<"llm_status_reported_v1">>, EventData, AgentIdentity) ->
    ModelName = maps:get(model_name, EventData, maps:get(<<"model_name">>, EventData, <<"unknown">>)),
    Status = maps:get(status, EventData, maps:get(<<"status">>, EventData, #{})),

    %% Build capability MRI (same logic as announce PM)
    SafeName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
    CapabilityMRI = <<"mri:capability:llm/", SafeName/binary>>,

    %% Dispatch update with new status metadata
    CmdParams = #{
        capability_mri => CapabilityMRI,
        agent_identity => AgentIdentity,
        metadata => #{
            type => <<"llm">>,
            status => Status
        }
    },
    dispatch_update_capability(CmdParams);
handle_event(_, _, _) ->
    ok.

dispatch_update_capability(CmdParams) ->
    case update_capability_v1:new(CmdParams) of
        {ok, Cmd} ->
            case maybe_update_capability:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    ok;
                {error, Reason} ->
                    logger:debug("[PM] Failed to update capability status: ~p", [Reason])
            end;
        {error, Reason} ->
            logger:debug("[PM] Invalid update command for status: ~p", [Reason])
    end.

get_agent_identity() ->
    application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>).
