%%% @doc mesh_subscription_added_v1 domain event
%%%
%%% Internal domain event: the daemon has accepted an
%%% agent-initiated subscribe-to-topic intent. The matching EMITTER
%%% (which will land in a follow-up slice once `receive_mesh_fact'
%%% is wired) reacts to this and calls `hecate_mesh:subscribe/2',
%%% installing the LISTENER callback that turns inbound facts into
%%% `mesh_fact_received_v1' events.
%%% @end
-module(mesh_subscription_added_v1).
-behaviour(evoq_event).

-export([new/1, new/2, to_map/1, from_map/1]).
-export([event_type/0]).

-record(mesh_subscription_added_v1, {
    topic        :: binary(),
    requested_at :: integer()
}).

-opaque mesh_subscription_added_v1() :: #mesh_subscription_added_v1{}.
-export_type([mesh_subscription_added_v1/0]).

event_type() -> <<"mesh_subscription_added_v1">>.

new(#{topic := T, requested_at := R}) ->
    new(T, R).

-spec new(binary(), integer()) -> mesh_subscription_added_v1().
new(Topic, RequestedAt) when is_binary(Topic), is_integer(RequestedAt) ->
    #mesh_subscription_added_v1{topic = Topic, requested_at = RequestedAt}.

-spec to_map(mesh_subscription_added_v1()) -> map().
to_map(#mesh_subscription_added_v1{topic = T, requested_at = R}) ->
    #{
        event_type   => <<"mesh_subscription_added_v1">>,
        topic        => T,
        requested_at => R
    }.

-spec from_map(map()) -> {ok, mesh_subscription_added_v1()} | {error, term()}.
from_map(#{topic := T, requested_at := R})
  when is_binary(T), is_integer(R) ->
    {ok, #mesh_subscription_added_v1{topic = T, requested_at = R}};
from_map(_) ->
    {error, invalid_mesh_subscription_added_event}.
