%%% @doc sale_archived_v1 event
%%% Emitted when a sale is archived (walking skeleton).
-module(sale_archived_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_sale_id/1, get_archived_at/1]).

-record(sale_archived_v1, {
    sale_id     :: binary(),
    archived_at :: integer()
}).

-export_type([sale_archived_v1/0]).
-opaque sale_archived_v1() :: #sale_archived_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> sale_archived_v1().
new(#{sale_id := SaleId}) ->
    #sale_archived_v1{
        sale_id     = SaleId,
        archived_at = erlang:system_time(millisecond)
    }.

-spec to_map(sale_archived_v1()) -> map().
to_map(#sale_archived_v1{} = E) ->
    #{
        event_type  => <<"sale_archived_v1">>,
        sale_id     => E#sale_archived_v1.sale_id,
        archived_at => E#sale_archived_v1.archived_at
    }.

-spec from_map(map()) -> {ok, sale_archived_v1()} | {error, term()}.
from_map(Map) ->
    SaleId = hecate_api_utils:get_field(sale_id, Map),
    case SaleId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #sale_archived_v1{
                sale_id     = SaleId,
                archived_at = hecate_api_utils:get_field(archived_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_sale_id(sale_archived_v1()) -> binary().
get_sale_id(#sale_archived_v1{sale_id = V}) -> V.

-spec get_archived_at(sale_archived_v1()) -> integer().
get_archived_at(#sale_archived_v1{archived_at = V}) -> V.
