%%% @doc Aggregate for the mesh_inbox domain.
%%%
%%% Singleton per daemon. Stream: `mesh_inbox'. Accepts the
%%% `receive_mesh_fact_v1' command (issued by the LISTENER on every
%%% inbound mesh FACT), produces `mesh_fact_received_v1' events.
%%% @end
-module(mesh_inbox_aggregate).
-behaviour(evoq_aggregate).

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/0]).

-spec state_module() -> module().
state_module() -> mesh_inbox_state.

-spec stream_id() -> binary().
stream_id() ->
    <<"mesh_inbox">>.

init(AggregateId) ->
    {ok, mesh_inbox_state:new(AggregateId)}.

execute(_State, #{command_type := receive_mesh_fact_v1} = Payload) ->
    maybe_receive_mesh_fact:handle_from_map(Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    mesh_inbox_state:apply_event(State, Event).
