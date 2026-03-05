%%% @doc license_announced_v1 event
%%% Emitted when a license is announced (pre-publish).
-module(license_announced_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_announced_at/1]).

-record(license_announced_v1, {
    license_id   :: binary(),
    announced_at :: integer()
}).

-export_type([license_announced_v1/0]).
-opaque license_announced_v1() :: #license_announced_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_announced_v1().
new(#{license_id := LicenseId}) ->
    #license_announced_v1{
        license_id = LicenseId,
        announced_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_announced_v1()) -> map().
to_map(#license_announced_v1{} = E) ->
    #{
        event_type => <<"license_announced_v1">>,
        license_id => E#license_announced_v1.license_id,
        announced_at => E#license_announced_v1.announced_at
    }.

-spec from_map(map()) -> {ok, license_announced_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_announced_v1{
                license_id = LicenseId,
                announced_at = hecate_api_utils:get_field(announced_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_license_id(license_announced_v1()) -> binary().
get_license_id(#license_announced_v1{license_id = V}) -> V.

-spec get_announced_at(license_announced_v1()) -> integer().
get_announced_at(#license_announced_v1{announced_at = V}) -> V.
