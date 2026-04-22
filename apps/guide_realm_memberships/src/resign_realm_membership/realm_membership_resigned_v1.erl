%%% @doc realm_membership_resigned_v1 event.
%%%
%%% Member-initiated departure. Published to the mesh
%%% (`{realm}.membership.resigned`) so the realm server's debounced
%%% rotation process manager can coalesce the rotation. Local state
%%% also flips MEMBERSHIP_RESIGNED. A concurrent
%%% `realm_membership_ended_v1 {reason: :resigned}` is appended in the
%%% same execute step.
%%% @end
-module(realm_membership_resigned_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(realm_membership_resigned_v1, {
    membership_id :: binary(),
    realm_id      :: binary() | undefined,
    member_did    :: binary() | undefined,
    resigned_at   :: integer()
}).

-opaque realm_membership_resigned_v1() :: #realm_membership_resigned_v1{}.
-export_type([realm_membership_resigned_v1/0]).

event_type() -> <<"realm_membership_resigned_v1">>.

-spec new(map()) -> {ok, realm_membership_resigned_v1()} | {error, term()}.
new(#{membership_id := M, resigned_at := At} = P) ->
    {ok, #realm_membership_resigned_v1{
        membership_id = M,
        realm_id      = maps:get(realm_id,   P, undefined),
        member_did    = maps:get(member_did, P, undefined),
        resigned_at   = At}};
new(_) ->
    {error, missing_fields}.

-spec to_map(realm_membership_resigned_v1()) -> map().
to_map(#realm_membership_resigned_v1{} = E) ->
    #{event_type    => event_type(),
      membership_id => E#realm_membership_resigned_v1.membership_id,
      realm_id      => E#realm_membership_resigned_v1.realm_id,
      member_did    => E#realm_membership_resigned_v1.member_did,
      resigned_at   => E#realm_membership_resigned_v1.resigned_at}.

-spec from_map(map()) -> {ok, realm_membership_resigned_v1()} | {error, term()}.
from_map(Map) -> new(Map).
