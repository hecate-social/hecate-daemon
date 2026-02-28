%%% @doc amend_license_pricing_v1 command
%%% Amends pricing fields on an existing license (before publish).
%%% Only provided (non-undefined) fields are changed.
-module(amend_license_pricing_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_license_id/1, get_selling_formula/1, get_license_type/1,
         get_fee_cents/1, get_fee_currency/1, get_duration_days/1,
         get_node_limit/1]).

-record(amend_license_pricing_v1, {
    license_id      :: binary(),
    selling_formula :: binary() | undefined,
    license_type    :: binary() | undefined,
    fee_cents       :: non_neg_integer() | undefined,
    fee_currency    :: binary() | undefined,
    duration_days   :: non_neg_integer() | undefined,
    node_limit      :: non_neg_integer() | undefined
}).

-export_type([amend_license_pricing_v1/0]).
-opaque amend_license_pricing_v1() :: #amend_license_pricing_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, amend_license_pricing_v1()} | {error, term()}.
new(#{license_id := LicenseId} = M) ->
    {ok, #amend_license_pricing_v1{
        license_id      = LicenseId,
        selling_formula = maps:get(selling_formula, M, undefined),
        license_type    = maps:get(license_type, M, undefined),
        fee_cents       = maps:get(fee_cents, M, undefined),
        fee_currency    = maps:get(fee_currency, M, undefined),
        duration_days   = maps:get(duration_days, M, undefined),
        node_limit      = maps:get(node_limit, M, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(amend_license_pricing_v1()) -> {ok, amend_license_pricing_v1()} | {error, term()}.
validate(#amend_license_pricing_v1{license_id = LicenseId}) when
    not is_binary(LicenseId); byte_size(LicenseId) =:= 0 ->
    {error, invalid_license_id};
validate(#amend_license_pricing_v1{} = Cmd) ->
    HasField = has_any_pricing_field(Cmd),
    case HasField of
        true -> {ok, Cmd};
        false -> {error, no_pricing_fields_provided}
    end.

-spec to_map(amend_license_pricing_v1()) -> map().
to_map(#amend_license_pricing_v1{} = Cmd) ->
    Base = #{
        <<"command_type">> => <<"amend_license_pricing">>,
        <<"license_id">> => Cmd#amend_license_pricing_v1.license_id
    },
    maybe_put(<<"selling_formula">>, Cmd#amend_license_pricing_v1.selling_formula,
    maybe_put(<<"license_type">>, Cmd#amend_license_pricing_v1.license_type,
    maybe_put(<<"fee_cents">>, Cmd#amend_license_pricing_v1.fee_cents,
    maybe_put(<<"fee_currency">>, Cmd#amend_license_pricing_v1.fee_currency,
    maybe_put(<<"duration_days">>, Cmd#amend_license_pricing_v1.duration_days,
    maybe_put(<<"node_limit">>, Cmd#amend_license_pricing_v1.node_limit,
    Base)))))).

-spec from_map(map()) -> {ok, amend_license_pricing_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #amend_license_pricing_v1{
                license_id      = LicenseId,
                selling_formula = hecate_api_utils:get_field(selling_formula, Map),
                license_type    = hecate_api_utils:get_field(license_type, Map),
                fee_cents       = hecate_api_utils:get_field(fee_cents, Map),
                fee_currency    = hecate_api_utils:get_field(fee_currency, Map),
                duration_days   = hecate_api_utils:get_field(duration_days, Map),
                node_limit      = hecate_api_utils:get_field(node_limit, Map)
            }}
    end.

%% Accessors

-spec get_license_id(amend_license_pricing_v1()) -> binary().
get_license_id(#amend_license_pricing_v1{license_id = V}) -> V.

-spec get_selling_formula(amend_license_pricing_v1()) -> binary() | undefined.
get_selling_formula(#amend_license_pricing_v1{selling_formula = V}) -> V.

-spec get_license_type(amend_license_pricing_v1()) -> binary() | undefined.
get_license_type(#amend_license_pricing_v1{license_type = V}) -> V.

-spec get_fee_cents(amend_license_pricing_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#amend_license_pricing_v1{fee_cents = V}) -> V.

-spec get_fee_currency(amend_license_pricing_v1()) -> binary() | undefined.
get_fee_currency(#amend_license_pricing_v1{fee_currency = V}) -> V.

-spec get_duration_days(amend_license_pricing_v1()) -> non_neg_integer() | undefined.
get_duration_days(#amend_license_pricing_v1{duration_days = V}) -> V.

-spec get_node_limit(amend_license_pricing_v1()) -> non_neg_integer() | undefined.
get_node_limit(#amend_license_pricing_v1{node_limit = V}) -> V.

%% Internal

has_any_pricing_field(#amend_license_pricing_v1{
    selling_formula = SF, license_type = LT, fee_cents = FC,
    fee_currency = FCur, duration_days = DD, node_limit = NL
}) ->
    SF =/= undefined orelse LT =/= undefined orelse FC =/= undefined orelse
    FCur =/= undefined orelse DD =/= undefined orelse NL =/= undefined.

maybe_put(_Key, undefined, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.
