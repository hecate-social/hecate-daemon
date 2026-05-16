%%% @doc Aggregate for the mesh_artifacts domain.
%%%
%%% Singleton per daemon. Stream: `mesh_artifacts'. The command
%%% `share_mesh_artifact_v1' is handled by `maybe_share_mesh_artifact',
%%% which calls `hecate_mesh:put_content/1' during handling and embeds
%%% the returned MCID in the event. The event records what happened;
%%% the bytes are already on the mesh by the time the event is stored.
%%% @end
-module(mesh_artifacts_aggregate).
-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/0]).

-spec state_module() -> module().
state_module() -> mesh_artifacts_state.

-spec stream_id() -> binary().
stream_id() -> <<"mesh_artifacts">>.

init(AggregateId) ->
    {ok, mesh_artifacts_state:new(AggregateId)}.

execute(_State, #{command_type := share_mesh_artifact_v1} = Payload) ->
    maybe_share_mesh_artifact:handle_from_map(Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    mesh_artifacts_state:apply_event(State, Event).
