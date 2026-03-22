%%% @doc offering_announced_v1 event
%%% Emitted when an offering is announced (pre-publish).
-module(offering_announced_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_offering_id/1, get_announced_at/1]).

-record(offering_announced_v1, {
    offering_id  :: binary(),
    announced_at :: integer()
}).

-export_type([offering_announced_v1/0]).
-opaque offering_announced_v1() :: #offering_announced_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> offering_announced_v1().
event_type() -> <<"offering_announced_v1">>.

new(#{offering_id := OfferingId}) ->
    #offering_announced_v1{
        offering_id = OfferingId,
        announced_at = erlang:system_time(millisecond)
    }.

-spec to_map(offering_announced_v1()) -> map().
to_map(#offering_announced_v1{} = E) ->
    #{
        event_type => <<"offering_announced_v1">>,
        offering_id => E#offering_announced_v1.offering_id,
        announced_at => E#offering_announced_v1.announced_at
    }.

-spec from_map(map()) -> {ok, offering_announced_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #offering_announced_v1{
                offering_id = OfferingId,
                announced_at = hecate_api_utils:get_field(announced_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_offering_id(offering_announced_v1()) -> binary().
get_offering_id(#offering_announced_v1{offering_id = V}) -> V.

-spec get_announced_at(offering_announced_v1()) -> integer().
get_announced_at(#offering_announced_v1{announced_at = V}) -> V.
