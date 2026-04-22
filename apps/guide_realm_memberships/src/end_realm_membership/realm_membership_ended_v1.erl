%%% @doc realm_membership_ended_v1 event.
%%%
%%% Terminal daemon-local event set by the end-membership handler.
%%% Records the reason (revoked | resigned | banned), the DID that
%%% ended the membership (admin for revoke, self for resign), and the
%%% timestamp. Flips MEMBERSHIP_ENDED in state and, when reason is
%%% :revoked, also flips MEMBERSHIP_REVOKED for history readability.
%%% @end
-module(realm_membership_ended_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(realm_membership_ended_v1, {
    membership_id :: binary(),
    reason        :: atom(),
    ended_by      :: binary() | undefined,
    ended_at      :: integer()
}).

-opaque realm_membership_ended_v1() :: #realm_membership_ended_v1{}.
-export_type([realm_membership_ended_v1/0]).

event_type() -> <<"realm_membership_ended_v1">>.

-spec new(map()) -> {ok, realm_membership_ended_v1()} | {error, term()}.
new(#{membership_id := M, reason := R, ended_at := At} = P) ->
    {ok, #realm_membership_ended_v1{
        membership_id = M,
        reason        = R,
        ended_by      = maps:get(ended_by, P, undefined),
        ended_at      = At}};
new(_) ->
    {error, missing_fields}.

-spec to_map(realm_membership_ended_v1()) -> map().
to_map(#realm_membership_ended_v1{membership_id = M, reason = R,
                                  ended_by = EB, ended_at = At}) ->
    #{event_type    => event_type(),
      membership_id => M,
      reason        => R,
      ended_by      => EB,
      ended_at      => At}.

-spec from_map(map()) -> {ok, realm_membership_ended_v1()} | {error, term()}.
from_map(Map) -> new(Map).
