%%% @doc Application module for guide_settings_lifecycle.
%%%
%%% On first boot, auto-detects linux_user + hostname and dispatches
%%% initiate_settings_v1. On restarts, the aggregate rejects with
%%% already_initiated (harmless).
-module(guide_settings_lifecycle_app).
-behaviour(application).

-export([start/2, stop/1]).

%% Suppress dialyzer warnings for dispatch calls
-dialyzer({nowarn_function, [auto_initiate_settings/0]}).

start(_StartType, _StartArgs) ->
    {ok, Pid} = guide_settings_lifecycle_sup:start_link(),
    auto_initiate_settings(),
    {ok, Pid}.

stop(_State) ->
    ok.

%% @doc Auto-initiate settings on daemon startup.
%% Dispatches initiate_settings_v1 with detected linux_user + hostname.
%% On restarts, the aggregate will reject with already_initiated — harmless.
%% Waits for the settings projection to be subscribed before dispatching,
%% so the event is guaranteed to be projected into SQLite.
auto_initiate_settings() ->
    spawn(fun() ->
        wait_for_projections(),
        User = list_to_binary(string:trim(os:cmd("whoami"), trailing, "\n")),
        Host = list_to_binary(net_adm:localhost()),
        Now = erlang:system_time(millisecond),
        Cmd = initiate_settings_v1:new(User, Host, Now),
        case maybe_initiate_settings:dispatch(Cmd) of
            {ok, _Version, _Events} ->
                logger:info("Settings initiated for ~s@~s", [User, Host]);
            {error, already_initiated} ->
                logger:debug("Settings already initiated for ~s@~s", [User, Host]);
            {error, Reason} ->
                logger:warning("Failed to auto-initiate settings: ~p", [Reason])
        end
    end).

%% @doc Wait until the settings projection process is alive and subscribed.
%% Polls every 200ms up to 30 attempts (6 seconds max).
wait_for_projections() ->
    wait_for_projections(30).

wait_for_projections(0) ->
    logger:warning("Settings projections not ready after timeout — dispatching anyway");
wait_for_projections(N) ->
    case whereis(settings_initiated_v1_to_settings) of
        Pid when is_pid(Pid) ->
            %% Projection is alive — give it a moment to finish subscribing
            timer:sleep(100),
            ok;
        undefined ->
            timer:sleep(200),
            wait_for_projections(N - 1)
    end.
