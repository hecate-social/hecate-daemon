%%% @doc license_pricing_amended_v1 event
%%% Emitted when pricing fields are amended on a license.
%%% Only non-undefined fields were changed.
-module(license_pricing_amended_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_license_id/1, get_selling_formula/1, get_license_type/1,
         get_fee_cents/1, get_fee_currency/1, get_duration_days/1,
         get_node_limit/1, get_amended_at/1]).

-record(license_pricing_amended_v1, {
    license_id      :: binary(),
    selling_formula :: binary() | undefined,
    license_type    :: binary() | undefined,
    fee_cents       :: non_neg_integer() | undefined,
    fee_currency    :: binary() | undefined,
    duration_days   :: non_neg_integer() | undefined,
    node_limit      :: non_neg_integer() | undefined,
    amended_at      :: integer()
}).

-export_type([license_pricing_amended_v1/0]).
-opaque license_pricing_amended_v1() :: #license_pricing_amended_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_pricing_amended_v1().
new(#{license_id := LicenseId} = M) ->
    #license_pricing_amended_v1{
        license_id      = LicenseId,
        selling_formula = maps:get(selling_formula, M, undefined),
        license_type    = maps:get(license_type, M, undefined),
        fee_cents       = maps:get(fee_cents, M, undefined),
        fee_currency    = maps:get(fee_currency, M, undefined),
        duration_days   = maps:get(duration_days, M, undefined),
        node_limit      = maps:get(node_limit, M, undefined),
        amended_at      = erlang:system_time(millisecond)
    }.

-spec to_map(license_pricing_amended_v1()) -> map().
to_map(#license_pricing_amended_v1{} = E) ->
    Base = #{
        <<"event_type">> => <<"license_pricing_amended_v1">>,
        <<"license_id">> => E#license_pricing_amended_v1.license_id,
        <<"amended_at">> => E#license_pricing_amended_v1.amended_at
    },
    maybe_put(<<"selling_formula">>, E#license_pricing_amended_v1.selling_formula,
    maybe_put(<<"license_type">>, E#license_pricing_amended_v1.license_type,
    maybe_put(<<"fee_cents">>, E#license_pricing_amended_v1.fee_cents,
    maybe_put(<<"fee_currency">>, E#license_pricing_amended_v1.fee_currency,
    maybe_put(<<"duration_days">>, E#license_pricing_amended_v1.duration_days,
    maybe_put(<<"node_limit">>, E#license_pricing_amended_v1.node_limit,
    Base)))))).

-spec from_map(map()) -> {ok, license_pricing_amended_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_pricing_amended_v1{
                license_id      = LicenseId,
                selling_formula = hecate_api_utils:get_field(selling_formula, Map),
                license_type    = hecate_api_utils:get_field(license_type, Map),
                fee_cents       = hecate_api_utils:get_field(fee_cents, Map),
                fee_currency    = hecate_api_utils:get_field(fee_currency, Map),
                duration_days   = hecate_api_utils:get_field(duration_days, Map),
                node_limit      = hecate_api_utils:get_field(node_limit, Map),
                amended_at      = hecate_api_utils:get_field(amended_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors

-spec get_license_id(license_pricing_amended_v1()) -> binary().
get_license_id(#license_pricing_amended_v1{license_id = V}) -> V.

-spec get_selling_formula(license_pricing_amended_v1()) -> binary() | undefined.
get_selling_formula(#license_pricing_amended_v1{selling_formula = V}) -> V.

-spec get_license_type(license_pricing_amended_v1()) -> binary() | undefined.
get_license_type(#license_pricing_amended_v1{license_type = V}) -> V.

-spec get_fee_cents(license_pricing_amended_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#license_pricing_amended_v1{fee_cents = V}) -> V.

-spec get_fee_currency(license_pricing_amended_v1()) -> binary() | undefined.
get_fee_currency(#license_pricing_amended_v1{fee_currency = V}) -> V.

-spec get_duration_days(license_pricing_amended_v1()) -> non_neg_integer() | undefined.
get_duration_days(#license_pricing_amended_v1{duration_days = V}) -> V.

-spec get_node_limit(license_pricing_amended_v1()) -> non_neg_integer() | undefined.
get_node_limit(#license_pricing_amended_v1{node_limit = V}) -> V.

-spec get_amended_at(license_pricing_amended_v1()) -> integer().
get_amended_at(#license_pricing_amended_v1{amended_at = V}) -> V.

%% Internal

maybe_put(_Key, undefined, Map) -> Map;
maybe_put(Key, Value, Map) -> Map#{Key => Value}.
