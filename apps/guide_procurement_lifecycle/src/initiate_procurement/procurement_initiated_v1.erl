%%% @doc procurement_initiated_v1 event
%%% Emitted when a consumer initiates a new procurement.
-module(procurement_initiated_v1).

-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).
-export([get_procurement_id/1, get_consumer_id/1, get_offering_id/1,
         get_plugin_id/1, get_author_id/1, get_initiated_at/1]).

-record(procurement_initiated_v1, {
    procurement_id :: binary(),
    consumer_id    :: binary(),
    offering_id    :: binary(),
    plugin_id      :: binary(),
    author_id      :: binary(),
    initiated_at   :: integer()
}).

-export_type([procurement_initiated_v1/0]).
-opaque procurement_initiated_v1() :: #procurement_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> procurement_initiated_v1().
event_type() -> <<"procurement_initiated_v1">>.

new(#{procurement_id := ProcurementId, consumer_id := ConsumerId,
      offering_id := OfferingId, plugin_id := PluginId,
      author_id := AuthorId}) ->
    #procurement_initiated_v1{
        procurement_id = ProcurementId,
        consumer_id = ConsumerId,
        offering_id = OfferingId,
        plugin_id = PluginId,
        author_id = AuthorId,
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(procurement_initiated_v1()) -> map().
to_map(#procurement_initiated_v1{} = E) ->
    #{
        event_type => <<"procurement_initiated_v1">>,
        procurement_id => E#procurement_initiated_v1.procurement_id,
        consumer_id => E#procurement_initiated_v1.consumer_id,
        offering_id => E#procurement_initiated_v1.offering_id,
        plugin_id => E#procurement_initiated_v1.plugin_id,
        author_id => E#procurement_initiated_v1.author_id,
        initiated_at => E#procurement_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, procurement_initiated_v1()} | {error, term()}.
from_map(Map) ->
    ProcurementId = hecate_api_utils:get_field(procurement_id, Map),
    ConsumerId = hecate_api_utils:get_field(consumer_id, Map),
    OfferingId = hecate_api_utils:get_field(offering_id, Map),
    PluginId = hecate_api_utils:get_field(plugin_id, Map),
    AuthorId = hecate_api_utils:get_field(author_id, Map),
    case {ProcurementId, ConsumerId, OfferingId, PluginId, AuthorId} of
        {undefined, _, _, _, _} -> {error, invalid_event};
        {_, undefined, _, _, _} -> {error, invalid_event};
        {_, _, undefined, _, _} -> {error, invalid_event};
        {_, _, _, undefined, _} -> {error, invalid_event};
        {_, _, _, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #procurement_initiated_v1{
                procurement_id = ProcurementId,
                consumer_id = ConsumerId,
                offering_id = OfferingId,
                plugin_id = PluginId,
                author_id = AuthorId,
                initiated_at = hecate_api_utils:get_field(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_procurement_id(procurement_initiated_v1()) -> binary().
get_procurement_id(#procurement_initiated_v1{procurement_id = V}) -> V.

-spec get_consumer_id(procurement_initiated_v1()) -> binary().
get_consumer_id(#procurement_initiated_v1{consumer_id = V}) -> V.

-spec get_offering_id(procurement_initiated_v1()) -> binary().
get_offering_id(#procurement_initiated_v1{offering_id = V}) -> V.

-spec get_plugin_id(procurement_initiated_v1()) -> binary().
get_plugin_id(#procurement_initiated_v1{plugin_id = V}) -> V.

-spec get_author_id(procurement_initiated_v1()) -> binary().
get_author_id(#procurement_initiated_v1{author_id = V}) -> V.

-spec get_initiated_at(procurement_initiated_v1()) -> integer().
get_initiated_at(#procurement_initiated_v1{initiated_at = V}) -> V.
