%%% @doc Aggregate for the mesh_publications domain.
%%%
%%% Singleton per daemon. Stream: `mesh_publications'. Accepts the
%%% publish_mesh_fact command, produces a mesh_fact_published_v1 event.
%%% No business rules to enforce at this layer — the agent decides what
%%% to publish; the daemon's job is to record + emit.
%%% @end
-module(mesh_publications_aggregate).
-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/0]).

-spec state_module() -> module().
state_module() -> mesh_publications_state.

-spec stream_id() -> binary().
stream_id() ->
    <<"mesh_publications">>.

init(AggregateId) ->
    {ok, mesh_publications_state:new(AggregateId)}.

%% evoq calls execute(State, Payload) — State FIRST.
execute(_State, #{command_type := publish_mesh_fact_v1} = Payload) ->
    maybe_publish_mesh_fact:handle_from_map(Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    mesh_publications_state:apply_event(State, Event).
