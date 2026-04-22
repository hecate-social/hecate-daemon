%%% @doc license_ended_v1 domain event.
%%%
%%% Recipient-local terminal event. Set by `maybe_end_license` when a
%%% revoke FACT or membership-end is observed. Clears CEK_USABLE in the
%%% aggregate state so the open-path refuses the license.
%%% @end
-module(license_ended_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(license_ended_v1, {
    license_id :: binary(),
    reason     :: atom(),
    ended_at   :: integer()
}).

-opaque license_ended_v1() :: #license_ended_v1{}.
-export_type([license_ended_v1/0]).

event_type() -> <<"license_ended_v1">>.

-spec new(map()) -> {ok, license_ended_v1()} | {error, term()}.
new(#{license_id := L, reason := R, ended_at := At}) ->
    {ok, #license_ended_v1{license_id = L, reason = R, ended_at = At}};
new(_) ->
    {error, missing_fields}.

-spec to_map(license_ended_v1()) -> map().
to_map(#license_ended_v1{license_id = L, reason = R, ended_at = At}) ->
    #{event_type => event_type(),
      license_id => L,
      reason     => R,
      ended_at   => At}.

-spec from_map(map()) -> {ok, license_ended_v1()} | {error, term()}.
from_map(Map) -> new(Map).
