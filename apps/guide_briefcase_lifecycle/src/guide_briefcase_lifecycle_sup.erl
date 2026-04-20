%%% @doc Top-level supervisor for guide_briefcase_lifecycle.
%%%
%%% Phase 1: no child processes — commands dispatch stateless through
%%% `reckon_evoq_adapter`. Later phases add:
%%%   - `briefcase_chunk_store` — content-addressed chunk I/O
%%%   - `briefcase_fs_watcher`  — reconciler (Phase 6)
%%%   - `briefcase_mesh_emitter` — pubsub event broadcast (Phase 2)
%%% @end
-module(guide_briefcase_lifecycle_sup).
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
