%%% @doc renew_license_v1 command
%%% Renews an expired license.
%%% Required: license_id.
-module(renew_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1]).

-record(renew_license_v1, {
    license_id :: binary()
}).

-export_type([renew_license_v1/0]).
-opaque renew_license_v1() :: #renew_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, renew_license_v1()} | {error, term()}.
new(#{license_id := LicenseId}) ->
    {ok, #renew_license_v1{
        license_id = LicenseId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(renew_license_v1()) -> {ok, renew_license_v1()} | {error, term()}.
validate(#renew_license_v1{license_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_license_id};
validate(#renew_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(renew_license_v1()) -> map().
to_map(#renew_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"renew_license">>,
        <<"license_id">> => Cmd#renew_license_v1.license_id
    }.

-spec from_map(map()) -> {ok, renew_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #renew_license_v1{
                license_id = LicenseId
            }}
    end.

%% Accessors
-spec get_license_id(renew_license_v1()) -> binary().
get_license_id(#renew_license_v1{license_id = V}) -> V.
