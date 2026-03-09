%%% @doc Process Manager: offering_terms_accepted_v1 -> initiate_procurement_v1
%%%
%%% When a consumer accepts offering terms, initiate a procurement process.
%%% Reads consumer_id, offering_id, plugin_id, author_id directly from the event.
%%% @end
-module(on_offering_terms_accepted_initiate_procurement).
-behaviour(evoq_event_handler).
-export([interested_in/0, init/1, handle_event/4]).

interested_in() -> [<<"offering_terms_accepted_v1">>].

init(_Config) -> {ok, #{}}.

handle_event(_EventType, Event, _Metadata, State) ->
    Data = maps:get(data, Event),
    LicenseId = hecate_api_utils:get_field(license_id, Data),
    ConsumerId = hecate_api_utils:get_field(consumer_id, Data),
    OfferingId = hecate_api_utils:get_field(offering_id, Data),
    PluginId = hecate_api_utils:get_field(plugin_id, Data),
    AuthorId = hecate_api_utils:get_field(author_id, Data),
    logger:info("[PM] Offering terms accepted for license ~s, initiating procurement", [LicenseId]),
    case initiate_procurement_v1:new(#{
        consumer_id => ConsumerId,
        offering_id => OfferingId,
        plugin_id => PluginId,
        author_id => AuthorId
    }) of
        {ok, Cmd} ->
            case maybe_initiate_procurement:dispatch(Cmd) of
                {ok, _, _} ->
                    logger:info("[PM] Procurement initiated for consumer ~s, plugin ~s", [ConsumerId, PluginId]);
                {error, Reason} ->
                    logger:error("[PM] Failed to initiate procurement for license ~s: ~p", [LicenseId, Reason])
            end;
        {error, Reason} ->
            logger:error("[PM] Failed to create procurement command for license ~s: ~p", [LicenseId, Reason])
    end,
    {ok, State}.
