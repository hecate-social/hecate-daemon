%%% @doc revoke_share_license_v1 command.
%%%
%%% Issuer-side authority action — ends a specific (license_id) grant.
%%% Dispatched by `guide_briefcase_lifecycle` revoke API (owner revokes
%%% a license they issued) or by admin tooling.
%%%
%%% Distinct from appstore `revoke_license_v1` — the latter governs
%%% plugin consumer licenses and lives in `guide_license_lifecycle`.
%%% Naming collision in `evoq_event_type_registry` (VM-global) forces
%%% the `share_` prefix on Phase D events.
%%% @end
-module(revoke_share_license_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_license_id/1, get_reason/1]).

-record(revoke_share_license_v1, {
    license_id :: binary(),
    reason     :: atom(),
    revoked_at :: integer()
}).

-opaque revoke_share_license_v1() :: #revoke_share_license_v1{}.
-export_type([revoke_share_license_v1/0]).

command_type() -> revoke_share_license_v1.

-spec new(map()) -> {ok, revoke_share_license_v1()} | {error, term()}.
new(#{license_id := L} = P) ->
    Reason = normalize_reason(maps:get(reason, P, revoked)),
    At     = maps:get(revoked_at, P, erlang:system_time(millisecond)),
    {ok, #revoke_share_license_v1{
        license_id = L,
        reason     = Reason,
        revoked_at = At}};
new(_) ->
    {error, missing_fields}.

-spec get_license_id(revoke_share_license_v1()) -> binary().
get_license_id(#revoke_share_license_v1{license_id = L}) -> L.

-spec get_reason(revoke_share_license_v1()) -> atom().
get_reason(#revoke_share_license_v1{reason = R}) -> R.

-spec to_map(revoke_share_license_v1()) -> map().
to_map(#revoke_share_license_v1{license_id = L, reason = R, revoked_at = At}) ->
    #{license_id => L, reason => R, revoked_at => At}.

-spec from_map(map()) -> {ok, revoke_share_license_v1()} | {error, term()}.
from_map(Map) -> new(Map).

%% --- Internal ---

normalize_reason(A) when is_atom(A) -> A;
normalize_reason(B) when is_binary(B) ->
    try binary_to_existing_atom(B, utf8)
    catch _:_ -> revoked
    end;
normalize_reason(_) -> revoked.
