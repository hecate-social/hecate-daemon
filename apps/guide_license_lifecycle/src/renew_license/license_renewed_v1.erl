%%% @doc license_renewed_v1 event
%%% Emitted when an expired license is renewed.
-module(license_renewed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_renewed_at/1]).

-record(license_renewed_v1, {
    license_id :: binary(),
    renewed_at :: integer()
}).

-export_type([license_renewed_v1/0]).
-opaque license_renewed_v1() :: #license_renewed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_renewed_v1().
new(#{license_id := LicenseId}) ->
    #license_renewed_v1{
        license_id = LicenseId,
        renewed_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_renewed_v1()) -> map().
to_map(#license_renewed_v1{} = E) ->
    #{
        event_type => <<"license_renewed_v1">>,
        license_id => E#license_renewed_v1.license_id,
        renewed_at => E#license_renewed_v1.renewed_at
    }.

-spec from_map(map()) -> {ok, license_renewed_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_renewed_v1{
                license_id = LicenseId,
                renewed_at = hecate_api_utils:get_field(renewed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_renewed_v1()) -> binary().
get_license_id(#license_renewed_v1{license_id = V}) -> V.

-spec get_renewed_at(license_renewed_v1()) -> integer().
get_renewed_at(#license_renewed_v1{renewed_at = V}) -> V.
