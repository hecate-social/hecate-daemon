%%% @doc offering_terms_accepted_v1 event
%%% Emitted when a consumer accepts offering terms.
%%% Lightweight — the offering data is already in aggregate state from initiate.
%%% Carries fee_cents echoed from state so the auto-grant PM can decide free vs paid.
-module(offering_terms_accepted_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_license_id/1, get_consumer_id/1, get_offering_id/1,
         get_plugin_id/1, get_author_id/1, get_fee_cents/1, get_accepted_at/1]).

-record(offering_terms_accepted_v1, {
    license_id   :: binary(),
    consumer_id  :: binary() | undefined,
    offering_id  :: binary() | undefined,
    plugin_id    :: binary() | undefined,
    author_id    :: binary() | undefined,
    fee_cents    :: non_neg_integer() | undefined,
    accepted_at  :: integer()
}).

-export_type([offering_terms_accepted_v1/0]).
-opaque offering_terms_accepted_v1() :: #offering_terms_accepted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> offering_terms_accepted_v1().
event_type() -> <<"offering_terms_accepted_v1">>.

new(#{license_id := LicenseId} = P) ->
    #offering_terms_accepted_v1{
        license_id  = LicenseId,
        consumer_id = maps:get(consumer_id, P, undefined),
        offering_id = maps:get(offering_id, P, undefined),
        plugin_id   = maps:get(plugin_id, P, undefined),
        author_id   = maps:get(author_id, P, undefined),
        fee_cents   = maps:get(fee_cents, P, undefined),
        accepted_at = erlang:system_time(millisecond)
    }.

-spec to_map(offering_terms_accepted_v1()) -> map().
to_map(#offering_terms_accepted_v1{} = E) ->
    #{
        event_type  => <<"offering_terms_accepted_v1">>,
        license_id  => E#offering_terms_accepted_v1.license_id,
        consumer_id => E#offering_terms_accepted_v1.consumer_id,
        offering_id => E#offering_terms_accepted_v1.offering_id,
        plugin_id   => E#offering_terms_accepted_v1.plugin_id,
        author_id   => E#offering_terms_accepted_v1.author_id,
        fee_cents   => E#offering_terms_accepted_v1.fee_cents,
        accepted_at => E#offering_terms_accepted_v1.accepted_at
    }.

-spec from_map(map()) -> {ok, offering_terms_accepted_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #offering_terms_accepted_v1{
                license_id  = LicenseId,
                consumer_id = hecate_api_utils:get_field(consumer_id, Map, undefined),
                offering_id = hecate_api_utils:get_field(offering_id, Map, undefined),
                plugin_id   = hecate_api_utils:get_field(plugin_id, Map, undefined),
                author_id   = hecate_api_utils:get_field(author_id, Map, undefined),
                fee_cents   = hecate_api_utils:get_field(fee_cents, Map, undefined),
                accepted_at = hecate_api_utils:get_field(accepted_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(offering_terms_accepted_v1()) -> binary().
get_license_id(#offering_terms_accepted_v1{license_id = V}) -> V.

-spec get_consumer_id(offering_terms_accepted_v1()) -> binary() | undefined.
get_consumer_id(#offering_terms_accepted_v1{consumer_id = V}) -> V.

-spec get_offering_id(offering_terms_accepted_v1()) -> binary() | undefined.
get_offering_id(#offering_terms_accepted_v1{offering_id = V}) -> V.

-spec get_plugin_id(offering_terms_accepted_v1()) -> binary() | undefined.
get_plugin_id(#offering_terms_accepted_v1{plugin_id = V}) -> V.

-spec get_author_id(offering_terms_accepted_v1()) -> binary() | undefined.
get_author_id(#offering_terms_accepted_v1{author_id = V}) -> V.

-spec get_fee_cents(offering_terms_accepted_v1()) -> non_neg_integer() | undefined.
get_fee_cents(#offering_terms_accepted_v1{fee_cents = V}) -> V.

-spec get_accepted_at(offering_terms_accepted_v1()) -> integer().
get_accepted_at(#offering_terms_accepted_v1{accepted_at = V}) -> V.
