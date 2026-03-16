%%% @doc GET /api/observer/stores/:store_id/events — Global event log ($all).
%%%
%%% All events across all streams in global causal order.
%%% Query params: offset=0, limit=50, type=event_type (optional filter)
%%% @end
-module(get_store_events_api).

-export([init/2, routes/0]).

routes() -> [{"/api/observer/stores/:store_id/events", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> handle_get(Req0, State);
        _ -> hecate_api_utils:method_not_allowed(Req0)
    end.

handle_get(Req0, _State) ->
    StoreIdBin = cowboy_req:binding(store_id, Req0),
    QS = cowboy_req:parse_qs(Req0),
    Offset = qs_int(<<"offset">>, QS, 0),
    Limit = qs_int(<<"limit">>, QS, 50),
    TypeFilter = proplists:get_value(<<"type">>, QS),

    StoreId = binary_to_existing_atom(StoreIdBin),
    Result = case TypeFilter of
        undefined ->
            evoq_event_store:read_all_global(StoreId, Offset, Limit);
        EventType ->
            evoq_event_store:read_events_by_types(StoreId, [EventType], Limit)
    end,
    case Result of
        {ok, Events} ->
            Items = [format_event(E) || E <- Events],
            hecate_api_utils:json_ok(#{
                items => Items,
                count => length(Items),
                store_id => StoreIdBin,
                offset => Offset,
                limit => Limit,
                type_filter => TypeFilter
            }, Req0);
        {error, Reason} ->
            hecate_api_utils:json_error(500, Reason, Req0)
    end.

format_event(EventMap) when is_map(EventMap) ->
    sanitize_event(EventMap);
format_event(Other) ->
    #{raw => iolist_to_binary(io_lib:format("~P", [Other, 30]))}.

sanitize_event(Map) ->
    maps:map(fun(_K, V) -> sanitize_value(V) end, Map).

sanitize_value(V) when is_binary(V) -> V;
sanitize_value(V) when is_integer(V) -> V;
sanitize_value(V) when is_float(V) -> V;
sanitize_value(V) when is_boolean(V) -> V;
sanitize_value(null) -> null;
sanitize_value(undefined) -> null;
sanitize_value(V) when is_atom(V) -> atom_to_binary(V);
sanitize_value(V) when is_list(V) -> [sanitize_value(E) || E <- V];
sanitize_value(V) when is_map(V) -> sanitize_event(V);
sanitize_value(V) -> iolist_to_binary(io_lib:format("~P", [V, 20])).

qs_int(Key, QS, Default) ->
    case proplists:get_value(Key, QS) of
        undefined -> Default;
        Bin -> binary_to_integer(Bin)
    end.
