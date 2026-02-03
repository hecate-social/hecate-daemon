%%% @doc LLM Status Heartbeat
%%% Periodically sends status updates for all known LLM capabilities.
%%% Tracks queue depth, tokens/sec, and availability.
-module(llm_status_heartbeat).
-behaviour(gen_server).

-export([start_link/0, report_request/1, report_completion/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

%% Suppress dialyzer warnings
-dialyzer({nowarn_function, [send_heartbeats/1, send_heartbeat/4]}).

-define(DEFAULT_HEARTBEAT_INTERVAL_MS, 30000). %% 30 seconds

-record(state, {
    agent_identity :: binary(),
    timer_ref :: reference() | undefined,
    heartbeat_interval :: non_neg_integer(),
    %% Metrics tracking
    active_requests :: non_neg_integer(),
    total_tokens :: non_neg_integer(),
    request_count :: non_neg_integer(),
    last_reset :: integer()
}).

%% API

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% @doc Report that a request has started (increments queue depth)
-spec report_request(binary()) -> ok.
report_request(_ModelName) ->
    gen_server:cast(?MODULE, request_started).

%% @doc Report that a request completed (decrements queue, records tokens)
-spec report_completion(binary(), non_neg_integer()) -> ok.
report_completion(_ModelName, TokenCount) ->
    gen_server:cast(?MODULE, {request_completed, TokenCount}).

%% Callbacks

init([]) ->
    AgentIdentity = get_agent_identity(),
    Interval = get_heartbeat_interval(),
    logger:info("[llm_status_heartbeat] Starting with interval: ~pms", [Interval]),
    %% Schedule first heartbeat
    TimerRef = erlang:send_after(Interval, self(), heartbeat),
    {ok, #state{
        agent_identity = AgentIdentity,
        timer_ref = TimerRef,
        heartbeat_interval = Interval,
        active_requests = 0,
        total_tokens = 0,
        request_count = 0,
        last_reset = erlang:system_time(millisecond)
    }}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(request_started, #state{active_requests = Active} = State) ->
    {noreply, State#state{active_requests = Active + 1}};

handle_cast({request_completed, TokenCount}, #state{
    active_requests = Active,
    total_tokens = Total,
    request_count = Count
} = State) ->
    NewActive = max(0, Active - 1),
    {noreply, State#state{
        active_requests = NewActive,
        total_tokens = Total + TokenCount,
        request_count = Count + 1
    }};

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(heartbeat, #state{heartbeat_interval = Interval} = State) ->
    NewState = send_heartbeats(State),
    %% Schedule next heartbeat
    TimerRef = erlang:send_after(Interval, self(), heartbeat),
    {noreply, NewState#state{timer_ref = TimerRef}};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = undefined}) ->
    ok;
terminate(_Reason, #state{timer_ref = TimerRef}) ->
    erlang:cancel_timer(TimerRef),
    ok.

%% Internal

send_heartbeats(#state{
    agent_identity = AgentID,
    active_requests = ActiveRequests,
    total_tokens = TotalTokens,
    request_count = RequestCount,
    last_reset = LastReset
} = State) ->
    %% Calculate tokens/sec
    Now = erlang:system_time(millisecond),
    ElapsedSec = max(1, (Now - LastReset) / 1000),
    AvgTokensPerSec = TotalTokens / ElapsedSec,

    %% Get known models from the poller
    case get_known_models() of
        {ok, Models} ->
            lists:foreach(fun(ModelName) ->
                send_heartbeat(ModelName, AgentID, ActiveRequests, AvgTokensPerSec)
            end, Models);
        {error, _} ->
            ok
    end,

    %% Reset counters periodically (every 5 minutes)
    case RequestCount > 100 orelse (Now - LastReset) > 300000 of
        true ->
            State#state{
                total_tokens = 0,
                request_count = 0,
                last_reset = Now
            };
        false ->
            State
    end.

send_heartbeat(ModelName, AgentID, QueueDepth, AvgTokensPerSec) ->
    %% Build capability MRI
    CapabilityMRI = build_capability_mri(AgentID, ModelName),

    %% Check if model is available (Ollama health)
    Available = check_model_available(),

    case update_llm_status_v1:new(#{
        capability_mri => CapabilityMRI,
        model_name => ModelName,
        agent_identity => AgentID,
        queue_depth => QueueDepth,
        avg_tokens_per_sec => AvgTokensPerSec,
        available => Available
    }) of
        {ok, Cmd} ->
            case maybe_update_llm_status:dispatch(Cmd) of
                {ok, _Version, _Events} ->
                    ok;
                {error, Reason} ->
                    logger:debug("[llm_status_heartbeat] Failed to update ~s: ~p",
                                [ModelName, Reason])
            end;
        {error, Reason} ->
            logger:debug("[llm_status_heartbeat] Invalid command for ~s: ~p",
                        [ModelName, Reason])
    end.

get_known_models() ->
    %% Try to get models from Ollama
    case llm_backend:list_models() of
        {ok, Models} ->
            Names = [maps:get(<<"name">>, M, <<>>) || M <- Models],
            {ok, [N || N <- Names, N =/= <<>>]};
        Error ->
            Error
    end.

check_model_available() ->
    case llm_backend:health() of
        ok -> true;
        _ -> false
    end.

build_capability_mri(AgentID, ModelName) ->
    case AgentID of
        <<"mri:agent:", Rest/binary>> ->
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:", Rest/binary, "/llm/", SafeModelName/binary>>;
        _ ->
            SafeModelName = binary:replace(ModelName, <<":">>, <<"-">>, [global]),
            <<"mri:capability:io.macula/unknown/llm/", SafeModelName/binary>>
    end.

get_agent_identity() ->
    case application:get_env(hecate, gateway_identity) of
        {ok, Identity} when is_binary(Identity) -> Identity;
        {ok, Identity} when is_list(Identity) -> list_to_binary(Identity);
        undefined -> <<"mri:agent:io.macula/hecate">>
    end.

get_heartbeat_interval() ->
    case application:get_env(serve_llm, status_interval_ms) of
        {ok, Interval} -> Interval;
        undefined -> ?DEFAULT_HEARTBEAT_INTERVAL_MS
    end.
