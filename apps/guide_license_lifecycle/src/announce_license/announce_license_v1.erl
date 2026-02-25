%%% @doc announce_license_v1 command
%%% Pre-publish step: announces a license for review.
-module(announce_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1]).

-record(announce_license_v1, {
    license_id :: binary()
}).

-export_type([announce_license_v1/0]).
-opaque announce_license_v1() :: #announce_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, announce_license_v1()} | {error, term()}.
new(#{license_id := LicenseId}) ->
    {ok, #announce_license_v1{license_id = LicenseId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(announce_license_v1()) -> {ok, announce_license_v1()} | {error, term()}.
validate(#announce_license_v1{license_id = LicenseId}) when
    not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, invalid_license_id};
validate(#announce_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(announce_license_v1()) -> map().
to_map(#announce_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"announce_license">>,
        <<"license_id">> => Cmd#announce_license_v1.license_id
    }.

-spec from_map(map()) -> {ok, announce_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #announce_license_v1{license_id = LicenseId}}
    end.

-spec get_license_id(announce_license_v1()) -> binary().
get_license_id(#announce_license_v1{license_id = V}) -> V.
