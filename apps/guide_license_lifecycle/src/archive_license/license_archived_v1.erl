%%% @doc license_archived_v1 event
%%% Emitted when a plugin license is archived (walking skeleton).
-module(license_archived_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_archived_at/1]).

-record(license_archived_v1, {
    license_id  :: binary(),
    archived_at :: integer()
}).

-export_type([license_archived_v1/0]).
-opaque license_archived_v1() :: #license_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_archived_v1().
new(#{license_id := LicenseId}) ->
    #license_archived_v1{
        license_id = LicenseId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_archived_v1()) -> map().
to_map(#license_archived_v1{} = E) ->
    #{
        event_type => <<"license_archived_v1">>,
        license_id => E#license_archived_v1.license_id,
        archived_at => E#license_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, license_archived_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_archived_v1{
                license_id = LicenseId,
                archived_at = hecate_api_utils:get_field(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_archived_v1()) -> binary().
get_license_id(#license_archived_v1{license_id = V}) -> V.

-spec get_archived_at(license_archived_v1()) -> integer().
get_archived_at(#license_archived_v1{archived_at = V}) -> V.
