%%% @doc LLM RPC Listener
%%% Listens for incoming mesh RPC requests (HOPEs) for LLM capabilities.
%%% Routes requests to handle_llm_rpc for processing.
-module(llm_rpc_listener).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings for mesh client calls
-dialyzer({nowarn_function, [init/1, terminate/2, subscribe_to_rpc_topic/1]}).

-record(state, {
    subscription_ref :: reference() | undefined,
    agent_identity :: binary(),
    request_count = 0 :: non_neg_integer()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    AgentIdentity = get_agent_identity(),
    logger:info("[llm_rpc_listener] Starting for identity: ~s", [AgentIdentity]),

    %% Subscribe to RPC topic for this agent's LLM capabilities
    SubRef = subscribe_to_rpc_topic(AgentIdentity),

    {ok, #state{
        subscription_ref = SubRef,
        agent_identity = AgentIdentity
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

%% Handle incoming RPC request (HOPE) from mesh
handle_info({mesh_rpc, RequestId, Payload}, State) ->
    #state{request_count = Count, agent_identity = AgentID} = State,
    logger:info("[llm_rpc_listener] Received RPC request: ~s", [RequestId]),

    %% Process asynchronously to not block listener
    spawn(fun() ->
        handle_llm_rpc:handle_request(RequestId, Payload, AgentID)
    end),

    {noreply, State#state{request_count = Count + 1}};

%% Handle mesh subscription message format
handle_info({mesh_message, Topic, Payload}, State) ->
    #state{request_count = Count, agent_identity = AgentID} = State,
    logger:debug("[llm_rpc_listener] Mesh message on ~s", [Topic]),

    %% Extract request ID and payload
    RequestId = maps:get(<<"request_id">>, Payload, generate_request_id()),

    spawn(fun() ->
        handle_llm_rpc:handle_request(RequestId, Payload, AgentID)
    end),

    {noreply, State#state{request_count = Count + 1}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{subscription_ref = undefined}) ->
    ok;
terminate(_Reason, #state{subscription_ref = SubRef}) ->
    %% Unsubscribe from mesh topic
    case hecate_mesh_client:unsubscribe(SubRef) of
        ok -> ok;
        {error, _} -> ok
    end.

%% Internal

subscribe_to_rpc_topic(AgentIdentity) ->
    %% Build RPC topic for this agent's LLM capabilities
    %% Format: hecate.llm.rpc.{agent-id}
    Topic = build_rpc_topic(AgentIdentity),
    logger:info("[llm_rpc_listener] Subscribing to topic: ~s", [Topic]),

    Callback = fun(Msg) ->
        self() ! {mesh_message, Topic, Msg}
    end,

    case hecate_mesh_client:subscribe(Topic, Callback) of
        {ok, SubRef} ->
            logger:info("[llm_rpc_listener] Subscribed successfully"),
            SubRef;
        {error, Reason} ->
            logger:warning("[llm_rpc_listener] Failed to subscribe: ~p", [Reason]),
            undefined
    end.

build_rpc_topic(AgentIdentity) ->
    %% Extract agent path from MRI
    AgentPath = case AgentIdentity of
        <<"mri:agent:", Rest/binary>> -> Rest;
        _ -> AgentIdentity
    end,
    %% Replace / with . for topic format
    SafePath = binary:replace(AgentPath, <<"/">>, <<".">>, [global]),
    <<"hecate.llm.rpc.", SafePath/binary>>.

get_agent_identity() ->
    case application:get_env(hecate, gateway_identity) of
        {ok, Identity} when is_binary(Identity) -> Identity;
        {ok, Identity} when is_list(Identity) -> list_to_binary(Identity);
        undefined -> <<"mri:agent:io.macula/hecate">>
    end.

generate_request_id() ->
    Rand = crypto:strong_rand_bytes(8),
    Hex = binary:encode_hex(Rand),
    <<"rpc-", Hex/binary>>.
