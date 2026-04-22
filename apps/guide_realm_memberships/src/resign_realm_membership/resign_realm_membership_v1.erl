%%% @doc resign_realm_membership_v1 command.
%%%
%%% Member-initiated departure. Returns TWO events from a single
%%% execute: `realm_membership_resigned_v1` (published to the mesh for
%%% the realm server's debounced rotation PM) AND
%%% `realm_membership_ended_v1 {reason: :resigned}` (terminal local
%%% transition). Semantically distinct from admin-revoke — different
%%% authority, different audit, different social contract.
%%% @end
-module(resign_realm_membership_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_membership_id/1]).

-record(resign_realm_membership_v1, {
    membership_id :: binary(),
    resigned_at   :: integer()
}).

-opaque resign_realm_membership_v1() :: #resign_realm_membership_v1{}.
-export_type([resign_realm_membership_v1/0]).

command_type() -> resign_realm_membership_v1.

-spec new(map()) -> {ok, resign_realm_membership_v1()} | {error, term()}.
new(#{membership_id := M} = P) ->
    At = maps:get(resigned_at, P, erlang:system_time(millisecond)),
    {ok, #resign_realm_membership_v1{
        membership_id = M,
        resigned_at   = At}};
new(_) ->
    {error, missing_fields}.

-spec get_membership_id(resign_realm_membership_v1()) -> binary().
get_membership_id(#resign_realm_membership_v1{membership_id = M}) -> M.

-spec to_map(resign_realm_membership_v1()) -> map().
to_map(#resign_realm_membership_v1{membership_id = M, resigned_at = At}) ->
    #{membership_id => M,
      resigned_at   => At}.

-spec from_map(map()) -> {ok, resign_realm_membership_v1()} | {error, term()}.
from_map(Map) -> new(Map).
