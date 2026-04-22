%%% @doc end_realm_membership_v1 command.
%%%
%%% Terminal transition for a realm membership. Parameterized by
%%% `reason :: :revoked | :resigned | :banned`. Replaces the previous
%%% `revoke_realm_membership_v1`; old revoked events are upcast to
%%% `realm_membership_ended_v1 {reason: :revoked}` inside
%%% `membership_state:apply_event/2`.
%%%
%%% Entry points:
%%%   - Self-resignation: `resign_realm_membership_v1` returns an ended
%%%     event alongside the resignation.
%%%   - Admin revoke: `listen_for_membership_revoked` dispatches
%%%     `end_realm_membership_v1 {reason: :revoked, ended_by: admin_did}`
%%%     when the realm server publishes on `{realm}.membership.revoked`.
%%% @end
-module(end_realm_membership_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_membership_id/1, get_reason/1]).

-record(end_realm_membership_v1, {
    membership_id :: binary(),
    reason        :: atom(),
    ended_by      :: binary() | undefined,
    ended_at      :: integer()
}).

-opaque end_realm_membership_v1() :: #end_realm_membership_v1{}.
-export_type([end_realm_membership_v1/0]).

command_type() -> end_realm_membership_v1.

-spec new(map()) -> {ok, end_realm_membership_v1()} | {error, term()}.
new(#{membership_id := M} = P) ->
    Reason = normalize_reason(maps:get(reason, P, revoked)),
    At     = maps:get(ended_at, P, erlang:system_time(millisecond)),
    {ok, #end_realm_membership_v1{
        membership_id = M,
        reason        = Reason,
        ended_by      = maps:get(ended_by, P, undefined),
        ended_at      = At}};
new(_) ->
    {error, missing_fields}.

-spec get_membership_id(end_realm_membership_v1()) -> binary().
get_membership_id(#end_realm_membership_v1{membership_id = M}) -> M.

-spec get_reason(end_realm_membership_v1()) -> atom().
get_reason(#end_realm_membership_v1{reason = R}) -> R.

-spec to_map(end_realm_membership_v1()) -> map().
to_map(#end_realm_membership_v1{membership_id = M, reason = R,
                                ended_by = EB, ended_at = At}) ->
    #{membership_id => M,
      reason        => R,
      ended_by      => EB,
      ended_at      => At}.

-spec from_map(map()) -> {ok, end_realm_membership_v1()} | {error, term()}.
from_map(Map) -> new(Map).

%% --- Internal ---

normalize_reason(A) when is_atom(A) -> A;
normalize_reason(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch _:_ -> revoked
    end;
normalize_reason(_) -> revoked.
