%%% @doc Merged projection: all sale lifecycle events -> sales ETS read model.
%%%
%%% Handles sale_initiated_v1 and sale_archived_v1 in a single projection
%%% to guarantee sequential event processing and avoid race conditions.
%%%
%%% Status bit flags defined in sale_status.hrl:
%%%   ?SALE_INITIATED = 1
%%%   ?SALE_ARCHIVED  = 32
%%% @end
-module(sale_lifecycle_to_sales).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

-include_lib("guide_sale_lifecycle/include/sale_status.hrl").

-define(TABLE, sales).

interested_in() ->
    [<<"sale_initiated_v1">>,
     <<"sale_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    EventType = get_event_type(Event),
    do_project(EventType, Data, State, RM).

%% --- sale_initiated_v1: INSERT new sale record ---

do_project(<<"sale_initiated_v1">>, Data, State, RM) ->
    SaleId = gf(sale_id, Data),
    Sale = #{
        sale_id        => SaleId,
        seller_id      => gf(seller_id, Data),
        procurement_id => gf(procurement_id, Data),
        offering_id    => gf(offering_id, Data),
        plugin_id      => gf(plugin_id, Data),
        status         => ?SALE_INITIATED,
        status_label   => <<"Initiated">>,
        initiated_at   => gf(initiated_at, Data),
        archived_at    => undefined
    },
    {ok, RM2} = evoq_read_model:put(SaleId, Sale, RM),
    {ok, State, RM2};

%% --- sale_archived_v1: UPDATE status flag + archived_at ---

do_project(<<"sale_archived_v1">>, Data, State, RM) ->
    SaleId = gf(sale_id, Data),
    case evoq_read_model:get(SaleId, RM) of
        {ok, #{status := S} = Existing} ->
            Updated = Existing#{
                status       => evoq_bit_flags:set(S, ?SALE_ARCHIVED),
                status_label => <<"Archived">>,
                archived_at  => gf(archived_at, Data)
            },
            {ok, RM2} = evoq_read_model:put(SaleId, Updated, RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end;

%% --- Unknown event type: skip ---

do_project(_Unknown, _Data, State, RM) ->
    {skip, State, RM}.

%% --- Helpers ---

get_event_type(#{event_type := T}) when is_binary(T) -> T;
get_event_type(#{<<"event_type">> := T}) when is_binary(T) -> T;
get_event_type(_) -> undefined.

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
