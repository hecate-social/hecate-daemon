%%% @doc Top-level supervisor for guide_settings_lifecycle.
%%%
%%% No emitters or PMs — settings are local-only, not published to mesh.
-module(guide_settings_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy => one_for_one,
        intensity => 10,
        period => 10
    },
    Children = [],
    {ok, {SupFlags, Children}}.
