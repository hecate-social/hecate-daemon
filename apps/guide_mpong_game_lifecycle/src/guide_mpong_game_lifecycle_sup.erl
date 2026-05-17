%%%-------------------------------------------------------------------
%%% @doc Top-level supervisor for MPong game lifecycle.
%%% @end
%%%-------------------------------------------------------------------
-module(guide_mpong_game_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Base = [
        #{id => run_game_engine_sup,
          start => {run_game_engine_sup, start_link, []},
          restart => permanent,
          type => supervisor},
        #{id => listen_game_state_sup,
          start => {listen_game_state_sup, start_link, []},
          restart => permanent,
          type => supervisor},
        #{id => mpong_lobby_seeker,
          start => {mpong_lobby_seeker, start_link, []},
          restart => permanent,
          type => worker}
    ],
    Children = Base ++ auto_host_demo_loop_children(),
    {ok, {SupFlags, Children}}.

%% Only run the public-demo auto-host loop when explicitly enabled via
%% application env (`{hecate, mpong_auto_host}') OR the OS env
%% `HECATE_MPONG_AUTO_HOST=true' (set in `~/.hecate/gitops/system/
%% hecate-daemon.env' on beam-cluster boxes designated for the demo).
%% Default off — user-installed daemons must never spam mpong matches.
auto_host_demo_loop_children() ->
    case auto_host_enabled() of
        true ->
            [#{id => auto_host_demo_loop_sup,
               start => {auto_host_demo_loop_sup, start_link, []},
               restart => permanent,
               type => supervisor}];
        _ ->
            []
    end.

auto_host_enabled() ->
    case application:get_env(hecate, mpong_auto_host, undefined) of
        true -> true;
        false -> false;
        _ -> os_env_true("HECATE_MPONG_AUTO_HOST")
    end.

os_env_true(Var) ->
    case os:getenv(Var) of
        "true"  -> true;
        "1"     -> true;
        "yes"   -> true;
        "TRUE"  -> true;
        _       -> false
    end.
