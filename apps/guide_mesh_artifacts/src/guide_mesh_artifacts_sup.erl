%%% @doc Top-level supervisor for guide_mesh_artifacts.
%%%
%%% No emitters: artifact bytes are stored via the SDK's content-sharing
%%% primitive directly during command handling; the produced event is
%%% an audit record, not the trigger for an external publish. Empty
%%% children list is correct.
-module(guide_mesh_artifacts_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [],
    {ok, {SupFlags, Children}}.
