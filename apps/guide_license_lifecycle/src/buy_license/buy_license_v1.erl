%%% @doc buy_license_v1 command
%%% Purchases a license (paid path).
%%% Required: license_id. Optional: payment_reference.
-module(buy_license_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_payment_reference/1]).

-record(buy_license_v1, {
    license_id        :: binary(),
    payment_reference :: binary() | undefined
}).

-export_type([buy_license_v1/0]).
-opaque buy_license_v1() :: #buy_license_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, buy_license_v1()} | {error, term()}.
new(#{license_id := LicenseId} = Params) ->
    {ok, #buy_license_v1{
        license_id = LicenseId,
        payment_reference = maps:get(payment_reference, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(buy_license_v1()) -> {ok, buy_license_v1()} | {error, term()}.
validate(#buy_license_v1{license_id = V}) when not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_license_id};
validate(#buy_license_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(buy_license_v1()) -> map().
to_map(#buy_license_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"buy_license">>,
        <<"license_id">> => Cmd#buy_license_v1.license_id,
        <<"payment_reference">> => Cmd#buy_license_v1.payment_reference
    }.

-spec from_map(map()) -> {ok, buy_license_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    PaymentRef = hecate_api_utils:get_field(payment_reference, Map, undefined),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #buy_license_v1{
                license_id = LicenseId,
                payment_reference = PaymentRef
            }}
    end.

%% Accessors
-spec get_license_id(buy_license_v1()) -> binary().
get_license_id(#buy_license_v1{license_id = V}) -> V.

-spec get_payment_reference(buy_license_v1()) -> binary() | undefined.
get_payment_reference(#buy_license_v1{payment_reference = V}) -> V.
