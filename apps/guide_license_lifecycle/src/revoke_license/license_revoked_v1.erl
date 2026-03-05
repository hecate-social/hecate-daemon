%%% @doc license_revoked_v1 event
%%% Emitted when a plugin license is revoked.
-module(license_revoked_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_reason/1, get_revoked_at/1]).

-record(license_revoked_v1, {
    license_id :: binary(),
    reason     :: binary() | undefined,
    revoked_at :: integer()
}).

-export_type([license_revoked_v1/0]).
-opaque license_revoked_v1() :: #license_revoked_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_revoked_v1().
new(#{license_id := LicenseId} = Params) ->
    #license_revoked_v1{
        license_id = LicenseId,
        reason = maps:get(reason, Params, undefined),
        revoked_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_revoked_v1()) -> map().
to_map(#license_revoked_v1{} = E) ->
    #{
        event_type => <<"license_revoked_v1">>,
        license_id => E#license_revoked_v1.license_id,
        reason => E#license_revoked_v1.reason,
        revoked_at => E#license_revoked_v1.revoked_at
    }.

-spec from_map(map()) -> {ok, license_revoked_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_revoked_v1{
                license_id = LicenseId,
                reason = hecate_api_utils:get_field(reason, Map, undefined),
                revoked_at = hecate_api_utils:get_field(revoked_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_revoked_v1()) -> binary().
get_license_id(#license_revoked_v1{license_id = V}) -> V.

-spec get_reason(license_revoked_v1()) -> binary() | undefined.
get_reason(#license_revoked_v1{reason = V}) -> V.

-spec get_revoked_at(license_revoked_v1()) -> integer().
get_revoked_at(#license_revoked_v1{revoked_at = V}) -> V.
