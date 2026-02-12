%%% @doc Process Manager: On LLM Removed, Retract Capability
%%% Subscribes to llm_removed_v1 events from serve_llm domain.
%%% Dispatches retract_capability_v1 commands to guide_node_lifecycle.
-module(on_llm_removed_retract_capability).
-behaviour(gen_server).

-include_lib("evoq/include/evoq_types.hrl").

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for calls to reckon_evoq_adapter (excluded from PLT)
-dialyzer({nowarn_function, [subscribe_to_llm_events/0]}).

-record(state, {
    subscription_ref :: reference() | undefined,
    agent_identity :: binary()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    AgentIdentity = get_agent_identity(),
    %% Subscribe to serve_llm events
    self() ! subscribe,
    {ok, #state{subscription_ref = undefined, agent_identity = AgentIdentity}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(subscribe, State) ->
    %% Subscribe to llm events from hecate_event_store
    SubRef = subscribe_to_llm_events(),
    {noreply, State#state{subscription_ref = SubRef}};
handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, #state{agent_identity = AgentId} = State) ->
    handle_event(EventType, EventData, AgentId),
    {noreply, State};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.

%% Internal

subscribe_to_llm_events() ->
    case reckon_evoq_adapter:subscribe(
        hecate_event_store,
        stream,
        <<"llms">>,
        <<"on_llm_removed_retract_capability">>,
        #{start_from => 0, subscriber_pid => self()}
    ) of
        {ok, SubRef} -> SubRef;
        {error, _} -> undefined
    end.

handle_event(<<"llm_removed_v1">>, EventData, AgentIdentity) ->
    %% Convert LLM removal to capability retraction
    ModelName = maps:get(model_name, EventData, maps:get(<<"model_name">>, EventData, <<"unknown">>)),

    %% Build capability MRI from model name (same logic as announce)
    CapabilityMRI = build_capability_mri(ModelName),

    %% Dispatch retract capability command
    dispatch_retract_capability(CapabilityMRI, AgentIdentity, <<"model_removed">>);
handle_event(_, _, _) ->
    %% Ignore other events
    ok.

build_capability_mri(ModelName) ->
    %% Sanitize model name for MRI (remove special chars)
    SafeName = sanitize_for_mri(ModelName),
    <<"mri:capability:llm/", SafeName/binary>>.

sanitize_for_mri(Name) when is_binary(Name) ->
    %% Replace : with - for MRI compatibility
    binary:replace(Name, <<":">>, <<"-">>, [global]).

dispatch_retract_capability(CapabilityMRI, AgentIdentity, Reason) ->
    case retract_capability_v1:new(CapabilityMRI, AgentIdentity, Reason) of
        {ok, Cmd} ->
            %% Dispatch to guide_node_lifecycle via evoq
            case maybe_retract_capability:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    logger:info("[PM] Retracted capability for LLM: ~p", [CapabilityMRI]);
                {error, Reason2} ->
                    logger:warning("[PM] Failed to retract capability: ~p", [Reason2])
            end;
        {error, Reason2} ->
            logger:warning("[PM] Invalid retract command: ~p", [Reason2])
    end.

get_agent_identity() ->
    application:get_env(hecate, gateway_identity, <<"mri:agent:io.macula/hecate">>).
