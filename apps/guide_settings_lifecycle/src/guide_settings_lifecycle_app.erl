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
auto_initiate_settings() ->
    spawn(fun() ->
        %% Small delay to allow event store subscriptions to settle
        timer:sleep(500),
        User = list_to_binary(string:trim(os:cmd("whoami"), trailing, "\n")),
        Host = list_to_binary(string:trim(os:cmd("hostname -s"), trailing, "\n")),
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
