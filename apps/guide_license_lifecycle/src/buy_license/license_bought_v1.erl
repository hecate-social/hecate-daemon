%%% @doc license_bought_v1 event
%%% Emitted when a license is purchased (paid path).
-module(license_bought_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_license_id/1, get_payment_reference/1, get_bought_at/1]).

-record(license_bought_v1, {
    license_id        :: binary(),
    payment_reference :: binary() | undefined,
    bought_at         :: integer()
}).

-export_type([license_bought_v1/0]).
-opaque license_bought_v1() :: #license_bought_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> license_bought_v1().
event_type() -> license_bought_v1.

new(#{license_id := LicenseId} = Params) ->
    #license_bought_v1{
        license_id = LicenseId,
        payment_reference = maps:get(payment_reference, Params, undefined),
        bought_at = erlang:system_time(millisecond)
    }.

-spec to_map(license_bought_v1()) -> map().
to_map(#license_bought_v1{} = E) ->
    #{
        event_type => <<"license_bought_v1">>,
        license_id => E#license_bought_v1.license_id,
        payment_reference => E#license_bought_v1.payment_reference,
        bought_at => E#license_bought_v1.bought_at
    }.

-spec from_map(map()) -> {ok, license_bought_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #license_bought_v1{
                license_id = LicenseId,
                payment_reference = hecate_api_utils:get_field(payment_reference, Map, undefined),
                bought_at = hecate_api_utils:get_field(bought_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(license_bought_v1()) -> binary().
get_license_id(#license_bought_v1{license_id = V}) -> V.

-spec get_payment_reference(license_bought_v1()) -> binary() | undefined.
get_payment_reference(#license_bought_v1{payment_reference = V}) -> V.

-spec get_bought_at(license_bought_v1()) -> integer().
get_bought_at(#license_bought_v1{bought_at = V}) -> V.
