%%% @doc revoke_license_v1 command
%%% Revokes an existing plugin license.
-module(revoke_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_reason/1]).

-record(revoke_license_v1, {
    license_id :: binary(),
    reason     :: binary() | undefined
}).

-export_type([revoke_license_v1/0]).
-opaque revoke_license_v1() :: #revoke_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, revoke_license_v1()} | {error, term()}.
new(#{license_id := LicenseId} = Params) ->
    {ok, #revoke_license_v1{
        license_id = LicenseId,
        reason = maps:get(reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(revoke_license_v1()) -> {ok, revoke_license_v1()} | {error, term()}.
validate(#revoke_license_v1{license_id = LicenseId}) when
    not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, invalid_license_id};
validate(#revoke_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(revoke_license_v1()) -> map().
to_map(#revoke_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"revoke_license">>,
        <<"license_id">> => Cmd#revoke_license_v1.license_id,
        <<"reason">> => Cmd#revoke_license_v1.reason
    }.

-spec from_map(map()) -> {ok, revoke_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    Reason = hecate_api_utils:get_field(reason, Map, undefined),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #revoke_license_v1{
                license_id = LicenseId,
                reason = Reason
            }}
    end.

%% Accessors
-spec get_license_id(revoke_license_v1()) -> binary().
get_license_id(#revoke_license_v1{license_id = V}) -> V.

-spec get_reason(revoke_license_v1()) -> binary() | undefined.
get_reason(#revoke_license_v1{reason = V}) -> V.
