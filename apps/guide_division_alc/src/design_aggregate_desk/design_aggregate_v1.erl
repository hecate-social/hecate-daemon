%%% @doc design_aggregate_v1 command
%%% Designs an aggregate within a division (DnA phase).
-module(design_aggregate_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_aggregate_name/1, get_description/1,
         get_stream_prefix/1, get_fields/1]).

-record(design_aggregate_v1, {
    division_id    :: binary(),
    aggregate_name :: binary(),
    description    :: binary() | undefined,
    stream_prefix  :: binary() | undefined,
    fields         :: list() | undefined
}).

-export_type([design_aggregate_v1/0]).
-opaque design_aggregate_v1() :: #design_aggregate_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, design_aggregate_v1()} | {error, term()}.
new(#{division_id := DivisionId, aggregate_name := AggregateName} = Params) ->
    {ok, #design_aggregate_v1{
        division_id = DivisionId,
        aggregate_name = AggregateName,
        description = maps:get(description, Params, undefined),
        stream_prefix = maps:get(stream_prefix, Params, undefined),
        fields = maps:get(fields, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(design_aggregate_v1()) -> {ok, design_aggregate_v1()} | {error, term()}.
validate(#design_aggregate_v1{division_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_division_id};
validate(#design_aggregate_v1{aggregate_name = N}) when
    not is_binary(N); byte_size(N) =:= 0 ->
    {error, invalid_aggregate_name};
validate(#design_aggregate_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(design_aggregate_v1()) -> map().
to_map(#design_aggregate_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"design_aggregate">>,
        <<"division_id">> => Cmd#design_aggregate_v1.division_id,
        <<"aggregate_name">> => Cmd#design_aggregate_v1.aggregate_name,
        <<"description">> => Cmd#design_aggregate_v1.description,
        <<"stream_prefix">> => Cmd#design_aggregate_v1.stream_prefix,
        <<"fields">> => Cmd#design_aggregate_v1.fields
    }.

-spec from_map(map()) -> {ok, design_aggregate_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    AggregateName = get_value(aggregate_name, Map),
    case {DivisionId, AggregateName} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #design_aggregate_v1{
                division_id = DivisionId,
                aggregate_name = AggregateName,
                description = get_value(description, Map, undefined),
                stream_prefix = get_value(stream_prefix, Map, undefined),
                fields = get_value(fields, Map, undefined)
            }}
    end.

%% Accessors
-spec get_division_id(design_aggregate_v1()) -> binary().
get_division_id(#design_aggregate_v1{division_id = V}) -> V.

-spec get_aggregate_name(design_aggregate_v1()) -> binary().
get_aggregate_name(#design_aggregate_v1{aggregate_name = V}) -> V.

-spec get_description(design_aggregate_v1()) -> binary() | undefined.
get_description(#design_aggregate_v1{description = V}) -> V.

-spec get_stream_prefix(design_aggregate_v1()) -> binary() | undefined.
get_stream_prefix(#design_aggregate_v1{stream_prefix = V}) -> V.

-spec get_fields(design_aggregate_v1()) -> list() | undefined.
get_fields(#design_aggregate_v1{fields = V}) -> V.

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
