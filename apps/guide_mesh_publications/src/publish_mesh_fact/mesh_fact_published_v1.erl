%%% @doc mesh_fact_published_v1 domain event
%%%
%%% Internal domain event that captures the daemon's *intent* to push
%%% a fact onto the mesh. The matching EMITTER
%%% (`mesh_fact_published_v1_to_mesh') reacts to this and performs the
%%% actual mesh publish — keeping the FACT-vs-EVENT distinction clean
%%% per the mesh-integration doctrine.
%%% @end
-module(mesh_fact_published_v1).
-behaviour(evoq_event).

-export([new/1, new/3, to_map/1, from_map/1]).
-export([event_type/0]).

-record(mesh_fact_published_v1, {
    topic        :: binary(),
    fact         :: map(),
    requested_at :: integer()
}).

-opaque mesh_fact_published_v1() :: #mesh_fact_published_v1{}.
-export_type([mesh_fact_published_v1/0]).

event_type() -> <<"mesh_fact_published_v1">>.

new(#{topic := T, fact := F, requested_at := R}) ->
    new(T, F, R).

-spec new(binary(), map(), integer()) -> mesh_fact_published_v1().
new(Topic, Fact, RequestedAt) when is_binary(Topic), is_map(Fact), is_integer(RequestedAt) ->
    #mesh_fact_published_v1{topic = Topic, fact = Fact, requested_at = RequestedAt}.

-spec to_map(mesh_fact_published_v1()) -> map().
to_map(#mesh_fact_published_v1{topic = T, fact = F, requested_at = R}) ->
    #{
        event_type   => <<"mesh_fact_published_v1">>,
        topic        => T,
        fact         => F,
        requested_at => R
    }.

-spec from_map(map()) -> {ok, mesh_fact_published_v1()} | {error, term()}.
from_map(#{topic := T, fact := F, requested_at := R})
  when is_binary(T), is_map(F), is_integer(R) ->
    {ok, #mesh_fact_published_v1{topic = T, fact = F, requested_at = R}};
from_map(_) ->
    {error, invalid_mesh_fact_published_event}.
