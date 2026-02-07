%%% @doc geo_check_worker - Periodic geo-restriction re-validation
%%%
%%% Periodically checks the local machine's geo-restriction status.
%%% If the machine becomes blocked (e.g., VPN change, IP change),
%%% notifies the daemon to take appropriate action.
-module(geo_check_worker).
-behaviour(gen_server).

-export([start_link/0, force_check/0, get_last_check/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-define(SERVER, ?MODULE).
-define(DEFAULT_INTERVAL, 3600000).  %% 1 hour

-record(state, {
    interval :: pos_integer(),
    last_check :: {calendar:datetime(), geo_check:check_result()} | undefined,
    timer_ref :: reference() | undefined
}).

%% @doc Start the worker
start_link() ->
    gen_server:start_link({local, ?SERVER}, ?MODULE, [], []).

%% @doc Force an immediate geo-check
-spec force_check() -> geo_check:check_result().
force_check() ->
    gen_server:call(?SERVER, force_check).

%% @doc Get the result of the last check
-spec get_last_check() -> {calendar:datetime(), geo_check:check_result()} | undefined.
get_last_check() ->
    gen_server:call(?SERVER, get_last_check).

%%% gen_server callbacks

init([]) ->
    Interval = application:get_env(geo_check, recheck_interval_ms, ?DEFAULT_INTERVAL),

    %% Schedule initial check after a short delay (let other services start)
    TimerRef = erlang:send_after(5000, self(), check),

    logger:info("[geo_check_worker] Started with interval ~p ms", [Interval]),
    {ok, #state{
        interval = Interval,
        last_check = undefined,
        timer_ref = TimerRef
    }}.

handle_call(force_check, _From, State) ->
    Result = do_check(State),
    {reply, element(2, Result), Result};

handle_call(get_last_check, _From, #state{last_check = LastCheck} = State) ->
    {reply, LastCheck, State};

handle_call(_Request, _From, State) ->
    {reply, {error, unknown_request}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(check, State) ->
    NewState = do_check(State),
    {noreply, NewState};

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, #state{timer_ref = TimerRef}) ->
    case TimerRef of
        undefined -> ok;
        Ref -> erlang:cancel_timer(Ref)
    end,
    ok.

%%% Internal functions

%% @private Perform the geo-check
do_check(#state{interval = Interval, timer_ref = OldRef} = State) ->
    %% Cancel old timer if exists
    case OldRef of
        undefined -> ok;
        Ref -> erlang:cancel_timer(Ref)
    end,

    %% Perform the check
    Result = geo_check:check_local(),
    Now = calendar:local_time(),

    %% Handle the result
    handle_check_result(Result),

    %% Schedule next check
    NewTimerRef = erlang:send_after(Interval, self(), check),

    State#state{
        last_check = {Now, Result},
        timer_ref = NewTimerRef
    }.

%% @private Handle the check result
handle_check_result(allowed) ->
    logger:debug("[geo_check_worker] Local check: allowed"),
    ok;
handle_check_result({blocked, CountryCode}) ->
    logger:warning("[geo_check_worker] Local check: BLOCKED (country: ~s)", [CountryCode]),
    %% Notify interested processes
    notify_blocked(CountryCode).

%% @private Notify processes about geo-restriction
notify_blocked(CountryCode) ->
    %% Try to notify hecate_mesh if it exists
    case whereis(hecate_mesh_client) of
        undefined ->
            ok;
        Pid ->
            Pid ! {geo_restricted, CountryCode}
    end,

    %% Also broadcast a message that other processes can subscribe to
    case whereis(hecate_events) of
        undefined -> ok;
        EventPid ->
            EventPid ! {event, geo_restricted, #{country => CountryCode}}
    end,

    ok.
