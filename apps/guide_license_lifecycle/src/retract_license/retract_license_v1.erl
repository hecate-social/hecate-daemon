%%% @doc retract_license_v1 command
%%% Pulls back an announced or published license to draft state.
-module(retract_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1]).

-record(retract_license_v1, {
    license_id :: binary()
}).

-export_type([retract_license_v1/0]).
-opaque retract_license_v1() :: #retract_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, retract_license_v1()} | {error, term()}.
new(#{license_id := LicenseId}) ->
    {ok, #retract_license_v1{license_id = LicenseId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(retract_license_v1()) -> {ok, retract_license_v1()} | {error, term()}.
validate(#retract_license_v1{license_id = LicenseId}) when
    not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, invalid_license_id};
validate(#retract_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(retract_license_v1()) -> map().
to_map(#retract_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"retract_license">>,
        <<"license_id">> => Cmd#retract_license_v1.license_id
    }.

-spec from_map(map()) -> {ok, retract_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #retract_license_v1{license_id = LicenseId}}
    end.

-spec get_license_id(retract_license_v1()) -> binary().
get_license_id(#retract_license_v1{license_id = V}) -> V.
