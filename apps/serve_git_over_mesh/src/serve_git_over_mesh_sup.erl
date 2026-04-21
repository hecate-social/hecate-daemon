%%% @doc Top-level supervisor for serve_git_over_mesh.
%%%
%%% Supervises two desks, each with its own supervisor:
%%%
%%%   - `initialize_repo_on_disk_sup` — reacts to `repo_initiated_v1`
%%%     by creating a bare git repo on disk and installing the
%%%     post-receive hook.
%%%   - `advertise_repo_procedures_sup` — reacts to `repo_initiated_v1`
%%%     by registering mesh procedure advertisements for each repo;
%%%     reacts to `repo_archived_v1` by unadvertising.
%%% @end
-module(serve_git_over_mesh_sup).
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
    Children = [
        #{id      => initialize_repo_on_disk_sup,
          start   => {initialize_repo_on_disk_sup, start_link, []},
          restart => permanent,
          type    => supervisor},
        #{id      => advertise_repo_procedures_sup,
          start   => {advertise_repo_procedures_sup, start_link, []},
          restart => permanent,
          type    => supervisor}
    ],
    {ok, {SupFlags, Children}}.
