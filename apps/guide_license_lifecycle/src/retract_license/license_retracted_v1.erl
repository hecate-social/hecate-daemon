%%% @doc license_retracted_v1 event
%%% Emitted when a license is retracted (pulled back to draft).
-module(license_retracted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_retracted_at/1]).

-record(license_retracted_v1, {
    license_id   :: binary(),
    retracted_at :: integer()
}).

-export_type([license_retracted_v1/0]).
-opaque license_retracted_v1() :: #license_retracted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_retracted_v1().
new(#{license_id := LicenseId}) ->
    #license_retracted_v1{
        license_id = LicenseId,
        retracted_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_retracted_v1()) -> map().
to_map(#license_retracted_v1{} = E) ->
    #{
        event_type => <<"license_retracted_v1">>,
        license_id => E#license_retracted_v1.license_id,
        retracted_at => E#license_retracted_v1.retracted_at
    }.

-spec from_map(map()) -> {ok, license_retracted_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_retracted_v1{
                license_id = LicenseId,
                retracted_at = hecate_api_utils:get_field(retracted_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_license_id(license_retracted_v1()) -> binary().
get_license_id(#license_retracted_v1{license_id = V}) -> V.

-spec get_retracted_at(license_retracted_v1()) -> integer().
get_retracted_at(#license_retracted_v1{retracted_at = V}) -> V.
