%%% @doc Top-level supervisor for guide_briefcase_lifecycle.
%%%
%%% Supervises mesh emitters for the briefcase CMD department. Each
%%% emitter subscribes to a specific domain event via
%%% `evoq_event_handler` and publishes an integration FACT to the mesh.
%%%
%%% Phase B wires:
%%%   - `file_shared_v1_to_mesh` — on each `file_shared_v1`, publish
%%%     `{realm}.briefcase.file_shared` FACT so realm peers can record
%%%     a placeholder for the file.
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
    Children = [
        emitter(file_shared_v1_to_mesh)
    ],
    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id      => Mod,
      start   => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent,
      type    => worker}.
