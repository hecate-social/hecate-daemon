%%% @doc offering_archived_v1 event
%%% Emitted when an offering is archived (walking skeleton).
-module(offering_archived_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_offering_id/1, get_archived_at/1]).

-record(offering_archived_v1, {
    offering_id :: binary(),
    archived_at :: integer()
}).

-export_type([offering_archived_v1/0]).
-opaque offering_archived_v1() :: #offering_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> offering_archived_v1().
event_type() -> <<"offering_archived_v1">>.

new(#{offering_id := OfferingId}) ->
    #offering_archived_v1{
        offering_id = OfferingId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(offering_archived_v1()) -> map().
to_map(#offering_archived_v1{} = E) ->
    #{
        event_type => <<"offering_archived_v1">>,
        offering_id => E#offering_archived_v1.offering_id,
        archived_at => E#offering_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, offering_archived_v1()} | {error, term()}.
from_map(Map) ->
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    case OfferingId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #offering_archived_v1{
                offering_id = OfferingId,
                archived_at = hecate_api_utils:get_field(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

-spec get_offering_id(offering_archived_v1()) -> binary().
get_offering_id(#offering_archived_v1{offering_id = V}) -> V.

-spec get_archived_at(offering_archived_v1()) -> integer().
get_archived_at(#offering_archived_v1{archived_at = V}) -> V.
