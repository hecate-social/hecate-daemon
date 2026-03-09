%%% @doc offering_published_v1 event
%%% Emitted when an offering is published (available on mesh).
-module(offering_published_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_offering_id/1, get_published_at/1]).

-record(offering_published_v1, {
    offering_id  :: binary(),
    published_at :: integer()
}).

-export_type([offering_published_v1/0]).
-opaque offering_published_v1() :: #offering_published_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> offering_published_v1().
new(#{offering_id := OfferingId}) ->
    #offering_published_v1{
        offering_id = OfferingId,
        published_at = erlang:system_time(millisecond)
    }.

-spec to_map(offering_published_v1()) -> map().
to_map(#offering_published_v1{} = E) ->
    #{
        event_type => <<"offering_published_v1">>,
        offering_id => E#offering_published_v1.offering_id,
        published_at => E#offering_published_v1.published_at
    }.

-spec from_map(map()) -> {ok, offering_published_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #offering_published_v1{
                offering_id = OfferingId,
                published_at = hecate_api_utils:get_field(published_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_offering_id(offering_published_v1()) -> binary().
get_offering_id(#offering_published_v1{offering_id = V}) -> V.

-spec get_published_at(offering_published_v1()) -> integer().
get_published_at(#offering_published_v1{published_at = V}) -> V.
