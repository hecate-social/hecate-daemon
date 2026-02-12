-module(measure_remote_latency).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(INITIAL_DELAY, 30000).
-define(INTERVAL, 300000).
-define(STALE_THRESHOLD, 600000). %% 10 minutes

-record(state, {timer_ref :: reference() | undefined}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    Ref = erlang:send_after(?INITIAL_DELAY, self(), measure),
    {ok, #state{timer_ref = Ref}}.

handle_call(_Req, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(measure, State) ->
    do_measure(),
    Ref = erlang:send_after(?INTERVAL, self(), measure),
    {noreply, State#state{timer_ref = Ref}};
handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = Ref}) ->
    case Ref of
        undefined -> ok;
        _ -> erlang:cancel_timer(Ref)
    end,
    ok.

do_measure() ->
    Now = erlang:system_time(millisecond),
    Threshold = Now - ?STALE_THRESHOLD,
    Sql = "SELECT mri, agent_id FROM remote_capabilities "
          "WHERE last_latency_check IS NULL OR last_latency_check < ?",
    case query_node_lifecycle_store:query(Sql, [Threshold]) of
        {ok, Rows} ->
            lists:foreach(fun([_Mri, AgentId]) ->
                measure_one(_Mri, AgentId, Now)
            end, Rows);
        {error, _Reason} ->
            ok
    end.

measure_one(Mri, AgentId, Now) ->
    case catch hecate_mesh_client:ping(AgentId) of
        {ok, LatencyMs} ->
            UpdateSql = "UPDATE remote_capabilities SET latency_ms = ?, last_latency_check = ? WHERE mri = ?",
            query_node_lifecycle_store:execute(UpdateSql, [LatencyMs, Now, Mri]);
        _ ->
            %% Failed to ping — just update the check time so we don't retry immediately
            UpdateSql = "UPDATE remote_capabilities SET last_latency_check = ? WHERE mri = ?",
            query_node_lifecycle_store:execute(UpdateSql, [Now, Mri])
    end.
