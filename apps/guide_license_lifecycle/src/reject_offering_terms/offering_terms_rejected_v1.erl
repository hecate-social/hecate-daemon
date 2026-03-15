%%% @doc offering_terms_rejected_v1 event
%%% Emitted when a consumer rejects the offering terms.
%%% Terminal state — license is effectively dead.
-module(offering_terms_rejected_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_license_id/1, get_reason/1, get_rejected_at/1]).

-record(offering_terms_rejected_v1, {
    license_id  :: binary(),
    reason      :: binary() | undefined,
    rejected_at :: integer()
}).

-export_type([offering_terms_rejected_v1/0]).
-opaque offering_terms_rejected_v1() :: #offering_terms_rejected_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> offering_terms_rejected_v1().
event_type() -> offering_terms_rejected_v1.

new(#{license_id := LicenseId} = Params) ->
    #offering_terms_rejected_v1{
        license_id = LicenseId,
        reason = maps:get(reason, Params, undefined),
        rejected_at = erlang:system_time(millisecond)
    }.

-spec to_map(offering_terms_rejected_v1()) -> map().
to_map(#offering_terms_rejected_v1{} = E) ->
    #{
        event_type => <<"offering_terms_rejected_v1">>,
        license_id => E#offering_terms_rejected_v1.license_id,
        reason => E#offering_terms_rejected_v1.reason,
        rejected_at => E#offering_terms_rejected_v1.rejected_at
    }.

-spec from_map(map()) -> {ok, offering_terms_rejected_v1()} | {error, term()}.
from_map(Map) ->
    LicenseId = hecate_api_utils:get_field(license_id, Map),
    case LicenseId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #offering_terms_rejected_v1{
                license_id = LicenseId,
                reason = hecate_api_utils:get_field(reason, Map, undefined),
                rejected_at = hecate_api_utils:get_field(rejected_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_license_id(offering_terms_rejected_v1()) -> binary().
get_license_id(#offering_terms_rejected_v1{license_id = V}) -> V.

-spec get_reason(offering_terms_rejected_v1()) -> binary() | undefined.
get_reason(#offering_terms_rejected_v1{reason = V}) -> V.

-spec get_rejected_at(offering_terms_rejected_v1()) -> integer().
get_rejected_at(#offering_terms_rejected_v1{rejected_at = V}) -> V.
