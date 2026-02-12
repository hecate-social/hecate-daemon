%%% @doc aggregate_designed_v1 event
%%% Emitted when an aggregate is designed within a division.
-module(aggregate_designed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_aggregate_name/1, get_description/1,
         get_stream_prefix/1, get_fields/1, get_designed_at/1]).

-record(aggregate_designed_v1, {
    division_id    :: binary(),
    aggregate_name :: binary(),
    description    :: binary() | undefined,
    stream_prefix  :: binary() | undefined,
    fields         :: list() | undefined,
    designed_at    :: integer()
}).

-export_type([aggregate_designed_v1/0]).
-opaque aggregate_designed_v1() :: #aggregate_designed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> aggregate_designed_v1().
new(#{division_id := DivisionId, aggregate_name := AggregateName} = Params) ->
    #aggregate_designed_v1{
        division_id = DivisionId,
        aggregate_name = AggregateName,
        description = maps:get(description, Params, undefined),
        stream_prefix = maps:get(stream_prefix, Params, undefined),
        fields = maps:get(fields, Params, undefined),
        designed_at = erlang:system_time(millisecond)
    }.

-spec to_map(aggregate_designed_v1()) -> map().
to_map(#aggregate_designed_v1{} = E) ->
    #{
        <<"event_type">> => <<"aggregate_designed_v1">>,
        <<"division_id">> => E#aggregate_designed_v1.division_id,
        <<"aggregate_name">> => E#aggregate_designed_v1.aggregate_name,
        <<"description">> => E#aggregate_designed_v1.description,
        <<"stream_prefix">> => E#aggregate_designed_v1.stream_prefix,
        <<"fields">> => E#aggregate_designed_v1.fields,
        <<"designed_at">> => E#aggregate_designed_v1.designed_at
    }.

-spec from_map(map()) -> {ok, aggregate_designed_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    AggregateName = get_value(aggregate_name, Map),
    case {DivisionId, AggregateName} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #aggregate_designed_v1{
                division_id = DivisionId,
                aggregate_name = AggregateName,
                description = get_value(description, Map, undefined),
                stream_prefix = get_value(stream_prefix, Map, undefined),
                fields = get_value(fields, Map, undefined),
                designed_at = get_value(designed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_division_id(aggregate_designed_v1()) -> binary().
get_division_id(#aggregate_designed_v1{division_id = V}) -> V.

-spec get_aggregate_name(aggregate_designed_v1()) -> binary().
get_aggregate_name(#aggregate_designed_v1{aggregate_name = V}) -> V.

-spec get_description(aggregate_designed_v1()) -> binary() | undefined.
get_description(#aggregate_designed_v1{description = V}) -> V.

-spec get_stream_prefix(aggregate_designed_v1()) -> binary() | undefined.
get_stream_prefix(#aggregate_designed_v1{stream_prefix = V}) -> V.

-spec get_fields(aggregate_designed_v1()) -> list() | undefined.
get_fields(#aggregate_designed_v1{fields = V}) -> V.

-spec get_designed_at(aggregate_designed_v1()) -> integer().
get_designed_at(#aggregate_designed_v1{designed_at = V}) -> V.

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
