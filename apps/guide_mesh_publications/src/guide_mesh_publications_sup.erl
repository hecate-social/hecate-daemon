%%% @doc Top-level supervisor for guide_mesh_publications.
%%%
%%% Wires the mesh emitter that reacts to `mesh_fact_published_v1'
%%% domain events and pushes them to the Macula mesh.
-module(guide_mesh_publications_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    SupFlags = #{strategy => one_for_one, intensity => 10, period => 10},
    Children = [
        emitter(mesh_fact_published_v1_to_mesh)
    ],
    {ok, {SupFlags, Children}}.

emitter(Mod) ->
    #{id => Mod,
      start => {evoq_event_handler, start_link, [Mod, #{}]},
      restart => permanent,
      type => worker}.
