%%% @doc Application module for guide_mesh_publications.
%%%
%%% Owns the `publish_mesh_fact' desk: an agent-facing command that
%%% records an intention to publish a fact, plus a mesh emitter that
%%% reacts to the resulting domain event and pushes the fact onto the
%%% Macula mesh. Doctrinally clean: agent HTTP -> CMD -> AGGREGATE ->
%%% DOMAIN EVENT -> EMITTER -> FACT.
%%% @end
-module(guide_mesh_publications_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_StartType, _StartArgs) ->
    guide_mesh_publications_sup:start_link().

stop(_State) ->
    ok.
