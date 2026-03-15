%%% @doc reject_offering_terms_v1 command
%%% Rejects offering terms — terminal state for the license.
%%% Required: license_id. Optional: reason.
-module(reject_offering_terms_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_license_id/1, get_reason/1]).

-record(reject_offering_terms_v1, {
    license_id :: binary(),
    reason     :: binary() | undefined
}).

-export_type([reject_offering_terms_v1/0]).
-opaque reject_offering_terms_v1() :: #reject_offering_terms_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, reject_offering_terms_v1()} | {error, term()}.
command_type() -> reject_offering_terms_v1.

new(#{license_id := LicenseId} = Params) ->
    {ok, #reject_offering_terms_v1{
        license_id = LicenseId,
        reason = maps:get(reason, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(reject_offering_terms_v1()) -> {ok, reject_offering_terms_v1()} | {error, term()}.
validate(#reject_offering_terms_v1{license_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_license_id};
validate(#reject_offering_terms_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(reject_offering_terms_v1()) -> map().
to_map(#reject_offering_terms_v1{} = Cmd) ->
    #{
        command_type => <<"reject_offering_terms">>,
        license_id => Cmd#reject_offering_terms_v1.license_id,
        reason => Cmd#reject_offering_terms_v1.reason
    }.

-spec from_map(map()) -> {ok, reject_offering_terms_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    Reason = hecate_api_utils:get_field(reason, Map, undefined),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #reject_offering_terms_v1{
                license_id = LicenseId,
                reason = Reason
            }}
    end.

%% Accessors
-spec get_license_id(reject_offering_terms_v1()) -> binary().
get_license_id(#reject_offering_terms_v1{license_id = V}) -> V.

-spec get_reason(reject_offering_terms_v1()) -> binary() | undefined.
get_reason(#reject_offering_terms_v1{reason = V}) -> V.
