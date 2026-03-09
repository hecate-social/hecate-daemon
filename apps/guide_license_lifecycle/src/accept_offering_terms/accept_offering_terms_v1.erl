%%% @doc accept_offering_terms_v1 command
%%% Lightweight consent confirmation. The offering data is already
%%% in the aggregate state from initiate_license — this is just
%%% the consumer saying "I accept the terms".
-module(accept_offering_terms_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1]).

-record(accept_offering_terms_v1, {
    license_id :: binary()
}).

-export_type([accept_offering_terms_v1/0]).
-opaque accept_offering_terms_v1() :: #accept_offering_terms_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, accept_offering_terms_v1()} | {error, term()}.
new(#{license_id := LicenseId}) ->
    {ok, #accept_offering_terms_v1{license_id = LicenseId}};
new(_) ->
    {error, missing_required_fields}.

-spec validate(accept_offering_terms_v1()) -> {ok, accept_offering_terms_v1()} | {error, term()}.
validate(#accept_offering_terms_v1{license_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_license_id};
validate(#accept_offering_terms_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(accept_offering_terms_v1()) -> map().
to_map(#accept_offering_terms_v1{} = C) ->
    #{
        <<"command_type">> => <<"accept_offering_terms">>,
        <<"license_id">>   => C#accept_offering_terms_v1.license_id
    }.

-spec from_map(map()) -> {ok, accept_offering_terms_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ -> {ok, #accept_offering_terms_v1{license_id = LicenseId}}
    end.

%% Accessors
-spec get_license_id(accept_offering_terms_v1()) -> binary().
get_license_id(#accept_offering_terms_v1{license_id = V}) -> V.
