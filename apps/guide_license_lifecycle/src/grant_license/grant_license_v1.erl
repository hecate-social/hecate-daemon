%%% @doc grant_license_v1 command
%%% Activates a license (PM dispatches after buy or free acceptance).
%%% Required: license_id. Optional: grant_reason.
-module(grant_license_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_license_id/1, get_grant_reason/1]).

-record(grant_license_v1, {
    license_id   :: binary(),
    grant_reason :: binary() | undefined
}).

-export_type([grant_license_v1/0]).
-opaque grant_license_v1() :: #grant_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, grant_license_v1()} | {error, term()}.
command_type() -> grant_license_v1.

new(#{license_id := LicenseId} = Params) ->
    {ok, #grant_license_v1{
        license_id = LicenseId,
        grant_reason = maps:get(grant_reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(grant_license_v1()) -> {ok, grant_license_v1()} | {error, term()}.
validate(#grant_license_v1{license_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_license_id};
validate(#grant_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(grant_license_v1()) -> map().
to_map(#grant_license_v1{} = Cmd) ->
    #{
        command_type => <<"grant_license">>,
        license_id => Cmd#grant_license_v1.license_id,
        grant_reason => Cmd#grant_license_v1.grant_reason
    }.

-spec from_map(map()) -> {ok, grant_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    GrantReason = hecate_api_utils:get_field(grant_reason, Map, undefined),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #grant_license_v1{
                license_id = LicenseId,
                grant_reason = GrantReason
            }}
    end.

%% Accessors
-spec get_license_id(grant_license_v1()) -> binary().
get_license_id(#grant_license_v1{license_id = V}) -> V.

-spec get_grant_reason(grant_license_v1()) -> binary() | undefined.
get_grant_reason(#grant_license_v1{grant_reason = V}) -> V.
