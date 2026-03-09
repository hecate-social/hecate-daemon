%%% @doc offering_retracted_v1 event
%%% Emitted when an offering is retracted (pulled back from mesh).
-module(offering_retracted_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_offering_id/1, get_retracted_at/1]).

-record(offering_retracted_v1, {
    offering_id  :: binary(),
    retracted_at :: integer()
}).

-export_type([offering_retracted_v1/0]).
-opaque offering_retracted_v1() :: #offering_retracted_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> offering_retracted_v1().
new(#{offering_id := OfferingId}) ->
    #offering_retracted_v1{
        offering_id = OfferingId,
        retracted_at = erlang:system_time(millisecond)
    }.

-spec to_map(offering_retracted_v1()) -> map().
to_map(#offering_retracted_v1{} = E) ->
    #{
        event_type => <<"offering_retracted_v1">>,
        offering_id => E#offering_retracted_v1.offering_id,
        retracted_at => E#offering_retracted_v1.retracted_at
    }.

-spec from_map(map()) -> {ok, offering_retracted_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #offering_retracted_v1{
                offering_id = OfferingId,
                retracted_at = hecate_api_utils:get_field(retracted_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_offering_id(offering_retracted_v1()) -> binary().
get_offering_id(#offering_retracted_v1{offering_id = V}) -> V.

-spec get_retracted_at(offering_retracted_v1()) -> integer().
get_retracted_at(#offering_retracted_v1{retracted_at = V}) -> V.
