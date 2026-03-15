%%% @doc archive_license_v1 command
%%% Archives a license (terminal state).
%%% Required: license_id.
-module(archive_license_v1).

-behaviour(evoq_command).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([command_type/0]).
-export([get_license_id/1]).

-record(archive_license_v1, {
    license_id :: binary()
}).

-export_type([archive_license_v1/0]).
-opaque archive_license_v1() :: #archive_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_license_v1()} | {error, term()}.
command_type() -> archive_license_v1.

new(#{license_id := LicenseId}) ->
    {ok, #archive_license_v1{
        license_id = LicenseId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_license_v1()) -> {ok, archive_license_v1()} | {error, term()}.
validate(#archive_license_v1{license_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_license_id};
validate(#archive_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(archive_license_v1()) -> map().
to_map(#archive_license_v1{} = Cmd) ->
    #{
        command_type => <<"archive_license">>,
        license_id => Cmd#archive_license_v1.license_id
    }.

-spec from_map(map()) -> {ok, archive_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #archive_license_v1{
                license_id = LicenseId
            }}
    end.

%% Accessors
-spec get_license_id(archive_license_v1()) -> binary().
get_license_id(#archive_license_v1{license_id = V}) -> V.
