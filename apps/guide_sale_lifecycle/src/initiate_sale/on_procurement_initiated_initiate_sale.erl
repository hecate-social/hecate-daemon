%%% @doc Process Manager: procurement_initiated_v1 -> initiate_sale_v1
%%%
%%% When a procurement is initiated, create a corresponding sale for the author.
%%% Reads author_id directly from the enriched procurement event.
%%% @end
-module(on_procurement_initiated_initiate_sale).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"procurement_initiated_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    ProcurementId = hecate_api_utils:get_field(procurement_id, Data),
    OfferingId = hecate_api_utils:get_field(offering_id, Data),
    PluginId = hecate_api_utils:get_field(plugin_id, Data),
    AuthorId = hecate_api_utils:get_field(author_id, Data),
    logger:info("[PM] Procurement ~s initiated, creating sale for author ~s", [ProcurementId, AuthorId]),
    case initiate_sale_v1:new(#{
        seller_id => AuthorId,
        procurement_id => ProcurementId,
        offering_id => OfferingId,
        plugin_id => PluginId
    }) of
        {ok, Cmd} ->
            case maybe_initiate_sale:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Sale initiated for author ~s, plugin ~s", [AuthorId, PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to initiate sale for procurement ~s: ~p", [ProcurementId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to create sale command for procurement ~s: ~p", [ProcurementId, Reason])
    end,
    {ok, State}.
