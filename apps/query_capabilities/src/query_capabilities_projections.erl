%%% @doc Projection subscription manager
%%% Subscribes to events from manage_capabilities and dispatches to projections.
-module(query_capabilities_projections).

-export([subscribe/0, handle_event/1]).

%% Suppress dialyzer warnings for calls to reckon_evoq (excluded from PLT)
-dialyzer({nowarn_function, [subscribe/0]}).

%% @doc Subscribe to events from command service
-spec subscribe() -> ok.
subscribe() ->
    %% Subscribe to all events from manage_capabilities ReckonDB
    reckon_evoq:subscribe(
        manage_capabilities_db,
        self(),
        fun handle_event/1
    ),
    ok.

%% @doc Handle incoming events from command service
%% Events arrive as evoq_event records or maps with the structure:
%% #{event_type => Binary, data => Map, metadata => Map, ...}
-spec handle_event(term()) -> ok.
handle_event(#{event_type := <<"capability_announced_v1">>, data := EventData, metadata := Metadata}) ->
    case capability_announced_v1:from_map(EventData) of
        {ok, Event} ->
            capability_announced_v1_to_capabilities:project(Event, Metadata);
        {error, Reason} ->
            logger:error("Failed to deserialize capability_announced_v1: ~p", [Reason]),
            ok
    end;

handle_event(#{event_type := <<"capability_updated_v1">>, data := EventData, metadata := Metadata}) ->
    case capability_updated_v1:from_map(EventData) of
        {ok, Event} ->
            capability_updated_v1_to_capabilities:project(Event, Metadata);
        {error, Reason} ->
            logger:error("Failed to deserialize capability_updated_v1: ~p", [Reason]),
            ok
    end;

handle_event(#{event_type := <<"capability_retracted_v1">>, data := EventData, metadata := Metadata}) ->
    case capability_retracted_v1:from_map(EventData) of
        {ok, Event} ->
            capability_retracted_v1_to_capabilities:project(Event, Metadata);
        {error, Reason} ->
            logger:error("Failed to deserialize capability_retracted_v1: ~p", [Reason]),
            ok
    end;

handle_event(#{event_type := EventType}) ->
    %% Unknown event type - ignore
    logger:debug("Ignoring unknown event type: ~p", [EventType]),
    ok;

handle_event(_Other) ->
    %% Not an event map - ignore
    ok.
