%%% @doc procurement_archived_v1 event
%%% Emitted when a procurement is archived (walking skeleton).
-module(procurement_archived_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_procurement_id/1, get_archived_at/1]).

-record(procurement_archived_v1, {
    procurement_id :: binary(),
    archived_at    :: integer()
}).

-export_type([procurement_archived_v1/0]).
-opaque procurement_archived_v1() :: #procurement_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> procurement_archived_v1().
event_type() -> <<"procurement_archived_v1">>.

new(#{procurement_id := ProcurementId}) ->
    #procurement_archived_v1{
        procurement_id = ProcurementId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(procurement_archived_v1()) -> map().
to_map(#procurement_archived_v1{} = E) ->
    #{
        event_type => <<"procurement_archived_v1">>,
        procurement_id => E#procurement_archived_v1.procurement_id,
        archived_at => E#procurement_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, procurement_archived_v1()} | {error, term()}.
from_map(Map) ->
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    case ProcurementId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #procurement_archived_v1{
                procurement_id = ProcurementId,
                archived_at = hecate_api_utils:get_field(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_procurement_id(procurement_archived_v1()) -> binary().
get_procurement_id(#procurement_archived_v1{procurement_id = V}) -> V.

-spec get_archived_at(procurement_archived_v1()) -> integer().
get_archived_at(#procurement_archived_v1{archived_at = V}) -> V.
