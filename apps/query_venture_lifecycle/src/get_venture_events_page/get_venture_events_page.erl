%%% @doc Query: read raw events from ReckonDB for a venture stream.
%%% Returns paginated events from the event store.
-module(get_venture_events_page).

-include_lib("evoq/include/evoq_types.hrl").

-export([get/1, get/3]).

-spec get(binary()) -> {ok, map()} | {error, term()}.
get(VentureId) ->
    get(VentureId, 0, 50).

-spec get(binary(), non_neg_integer(), pos_integer()) -> {ok, map()} | {error, term()}.
get(VentureId, Offset, Limit) ->
    case reckon_evoq_adapter:read(dev_studio_store, VentureId, Offset, Limit, forward) of
        {ok, Events} ->
            FormattedEvents = [format_event(E) || E <- Events],
            {ok, #{
                events => FormattedEvents,
                offset => Offset,
                limit => Limit,
                count => length(FormattedEvents)
            }};
        {error, Reason} ->
            {error, Reason}
    end.

format_event(#evoq_event{event_type = Type, data = Data, version = Version, timestamp = Ts}) ->
    #{
        event_type => Type,
        data => Data,
        version => Version,
        timestamp => Ts
    };
format_event(Event) when is_map(Event) ->
    #{
        event_type => maps:get(<<"event_type">>, Event, maps:get(event_type, Event, unknown)),
        data => Event,
        version => maps:get(<<"version">>, Event, maps:get(version, Event, undefined)),
        timestamp => maps:get(<<"timestamp">>, Event, maps:get(timestamp, Event, undefined))
    };
format_event(Event) ->
    #{data => Event}.
