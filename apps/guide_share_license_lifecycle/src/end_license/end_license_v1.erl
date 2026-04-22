%%% @doc end_license_v1 command.
%%%
%%% Recipient-side terminal transition. Dispatched by
%%% `listen_for_license_revoked` (live revoke) and (Session 3+) by
%%% catch-up worker when a revoke was missed while offline.
%%% @end
-module(end_license_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_license_id/1]).

-record(end_license_v1, {
    license_id :: binary(),
    reason     :: atom(),
    ended_at   :: integer()
}).

-opaque end_license_v1() :: #end_license_v1{}.
-export_type([end_license_v1/0]).

command_type() -> end_license_v1.

-spec new(map()) -> {ok, end_license_v1()} | {error, term()}.
new(#{license_id := L, reason := R} = P) ->
    At = maps:get(ended_at, P, erlang:system_time(millisecond)),
    {ok, #end_license_v1{license_id = L, reason = R, ended_at = At}};
new(_) ->
    {error, missing_fields}.

-spec get_license_id(end_license_v1()) -> binary().
get_license_id(#end_license_v1{license_id = L}) -> L.

-spec to_map(end_license_v1()) -> map().
to_map(#end_license_v1{license_id = L, reason = R, ended_at = At}) ->
    #{license_id => L, reason => R, ended_at => At}.

-spec from_map(map()) -> {ok, end_license_v1()} | {error, term()}.
from_map(Map) -> new(Map).
