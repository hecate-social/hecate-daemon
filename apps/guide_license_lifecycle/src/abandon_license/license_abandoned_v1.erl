%%% @doc license_abandoned_v1 event
%%% Emitted when a consumer abandons a license.
%%% Terminal state — license is effectively dead.
-module(license_abandoned_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_license_id/1, get_reason/1, get_abandoned_at/1]).

-record(license_abandoned_v1, {
    license_id   :: binary(),
    reason       :: binary() | undefined,
    abandoned_at :: integer()
}).

-export_type([license_abandoned_v1/0]).
-opaque license_abandoned_v1() :: #license_abandoned_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_abandoned_v1().
event_type() -> <<"license_abandoned_v1">>.

new(#{license_id := LicenseId} = Params) ->
    #license_abandoned_v1{
        license_id = LicenseId,
        reason = maps:get(reason, Params, undefined),
        abandoned_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_abandoned_v1()) -> map().
to_map(#license_abandoned_v1{} = E) ->
    #{
        event_type => <<"license_abandoned_v1">>,
        license_id => E#license_abandoned_v1.license_id,
        reason => E#license_abandoned_v1.reason,
        abandoned_at => E#license_abandoned_v1.abandoned_at
    }.

-spec from_map(map()) -> {ok, license_abandoned_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_abandoned_v1{
                license_id = LicenseId,
                reason = hecate_api_utils:get_field(reason, Map, undefined),
                abandoned_at = hecate_api_utils:get_field(abandoned_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_abandoned_v1()) -> binary().
get_license_id(#license_abandoned_v1{license_id = V}) -> V.

-spec get_reason(license_abandoned_v1()) -> binary() | undefined.
get_reason(#license_abandoned_v1{reason = V}) -> V.

-spec get_abandoned_at(license_abandoned_v1()) -> integer().
get_abandoned_at(#license_abandoned_v1{abandoned_at = V}) -> V.
