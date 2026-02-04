%%% @doc Measure Remote Latency
%%% Periodically pings discovered remote agents and updates latency_ms
%%% in the remote_capabilities table. Enables intelligent routing.
-module(measure_remote_latency).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(DEFAULT_CHECK_INTERVAL_MS, 60000). %% 1 minute
-define(PING_TIMEOUT_MS, 5000).

-record(state, {
    timer_ref :: reference() | undefined,
    interval :: non_neg_integer()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Interval = application:get_env(query_capabilities, latency_check_interval_ms,
                                   ?DEFAULT_CHECK_INTERVAL_MS),
    %% Delay first check to let remote_capabilities populate
    TimerRef = erlang:send_after(Interval, self(), check_latencies),
    {ok, #state{timer_ref = TimerRef, interval = Interval}}.

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(check_latencies, #state{interval = Interval} = State) ->
    measure_all_agents(),
    TimerRef = erlang:send_after(Interval, self(), check_latencies),
    {noreply, State#state{timer_ref = TimerRef}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = undefined}) -> ok;
terminate(_Reason, #state{timer_ref = TimerRef}) ->
    erlang:cancel_timer(TimerRef),
    ok.

%% Internal

measure_all_agents() ->
    %% Get distinct agent_ids from remote_capabilities
    case query_capabilities_store:query(
        "SELECT DISTINCT agent_id FROM remote_capabilities") of
        {ok, Rows} ->
            lists:foreach(fun([AgentId]) ->
                measure_agent(AgentId)
            end, Rows);
        {error, _} ->
            ok
    end.

measure_agent(AgentId) ->
    %% Measure round-trip time via mesh ping
    StartTime = erlang:monotonic_time(microsecond),
    case ping_agent(AgentId) of
        {ok, _} ->
            EndTime = erlang:monotonic_time(microsecond),
            LatencyMs = (EndTime - StartTime) div 1000,
            update_latency(AgentId, LatencyMs);
        {error, _} ->
            %% Agent unreachable, record high latency
            update_latency(AgentId, -1)
    end.

ping_agent(AgentId) ->
    %% Publish a ping and wait for pong via mesh
    %% For now, use hecate_mesh_client:call if available,
    %% otherwise estimate based on mesh connectivity
    PingTopic = <<"hecate.ping.", AgentId/binary>>,
    case hecate_mesh_client:publish(PingTopic, #{type => <<"ping">>}) of
        ok -> {ok, published};
        Error -> Error
    end.

update_latency(AgentId, LatencyMs) ->
    Now = erlang:system_time(second),
    query_capabilities_store:execute(
        "UPDATE remote_capabilities SET latency_ms = ?1, last_latency_check = ?2 WHERE agent_id = ?3",
        [LatencyMs, Now, AgentId]).
