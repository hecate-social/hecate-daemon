%%% @doc Top-level supervisor for guide_repo_lifecycle.
%%%
%%% Phase 1: no child processes — commands dispatch stateless through
%%% `reckon_evoq_adapter`. Later phases add:
%%%   - `serve_git_over_mesh` children (git RPC subprocess manager)
%%%   - `announce_ref_updates` children (post-receive hook emitter)
%%% @end
-module(guide_repo_lifecycle_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{
        strategy  => one_for_one,
        intensity => 10,
        period    => 10
    },
    Children = [],
    {ok, {SupFlags, Children}}.
