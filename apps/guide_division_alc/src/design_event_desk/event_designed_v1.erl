%%% @doc event_designed_v1 event
%%% Emitted when an event is designed within a division.
-module(event_designed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_event_name/1, get_description/1,
         get_aggregate_name/1, get_fields/1, get_designed_at/1]).

-record(event_designed_v1, {
    division_id    :: binary(),
    event_name     :: binary(),
    description    :: binary() | undefined,
    aggregate_name :: binary() | undefined,
    fields         :: list() | undefined,
    designed_at    :: integer()
}).

-export_type([event_designed_v1/0]).
-opaque event_designed_v1() :: #event_designed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> event_designed_v1().
new(#{division_id := DivisionId, event_name := EventName} = Params) ->
    #event_designed_v1{
        division_id = DivisionId,
        event_name = EventName,
        description = maps:get(description, Params, undefined),
        aggregate_name = maps:get(aggregate_name, Params, undefined),
        fields = maps:get(fields, Params, undefined),
        designed_at = erlang:system_time(millisecond)
    }.

-spec to_map(event_designed_v1()) -> map().
to_map(#event_designed_v1{} = E) ->
    #{
        <<"event_type">> => <<"event_designed_v1">>,
        <<"division_id">> => E#event_designed_v1.division_id,
        <<"event_name">> => E#event_designed_v1.event_name,
        <<"description">> => E#event_designed_v1.description,
        <<"aggregate_name">> => E#event_designed_v1.aggregate_name,
        <<"fields">> => E#event_designed_v1.fields,
        <<"designed_at">> => E#event_designed_v1.designed_at
    }.

-spec from_map(map()) -> {ok, event_designed_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    EventName = get_value(event_name, Map),
    case {DivisionId, EventName} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #event_designed_v1{
                division_id = DivisionId,
                event_name = EventName,
                description = get_value(description, Map, undefined),
                aggregate_name = get_value(aggregate_name, Map, undefined),
                fields = get_value(fields, Map, undefined),
                designed_at = get_value(designed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_division_id(event_designed_v1()) -> binary().
get_division_id(#event_designed_v1{division_id = V}) -> V.

-spec get_event_name(event_designed_v1()) -> binary().
get_event_name(#event_designed_v1{event_name = V}) -> V.

-spec get_description(event_designed_v1()) -> binary() | undefined.
get_description(#event_designed_v1{description = V}) -> V.

-spec get_aggregate_name(event_designed_v1()) -> binary() | undefined.
get_aggregate_name(#event_designed_v1{aggregate_name = V}) -> V.

-spec get_fields(event_designed_v1()) -> list() | undefined.
get_fields(#event_designed_v1{fields = V}) -> V.

-spec get_designed_at(event_designed_v1()) -> integer().
get_designed_at(#event_designed_v1{designed_at = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) ->
    get_value(Key, Map, undefined).

get_value(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
