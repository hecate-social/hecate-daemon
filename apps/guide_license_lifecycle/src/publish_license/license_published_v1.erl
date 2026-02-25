%%% @doc license_published_v1 event
%%% Emitted when a license is published and available for purchase.
-module(license_published_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_published_at/1]).

-record(license_published_v1, {
    license_id   :: binary(),
    published_at :: integer()
}).

-export_type([license_published_v1/0]).
-opaque license_published_v1() :: #license_published_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_published_v1().
new(#{license_id := LicenseId}) ->
    #license_published_v1{
        license_id = LicenseId,
        published_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_published_v1()) -> map().
to_map(#license_published_v1{} = E) ->
    #{
        <<"event_type">> => <<"license_published_v1">>,
        <<"license_id">> => E#license_published_v1.license_id,
        <<"published_at">> => E#license_published_v1.published_at
    }.

-spec from_map(map()) -> {ok, license_published_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_published_v1{
                license_id = LicenseId,
                published_at = hecate_api_utils:get_field(published_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_license_id(license_published_v1()) -> binary().
get_license_id(#license_published_v1{license_id = V}) -> V.

-spec get_published_at(license_published_v1()) -> integer().
get_published_at(#license_published_v1{published_at = V}) -> V.
