%%% @doc design_event_v1 command
%%% Designs an event within a division (DnA phase).
-module(design_event_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_event_name/1, get_description/1,
         get_aggregate_name/1, get_fields/1]).

-record(design_event_v1, {
    division_id    :: binary(),
    event_name     :: binary(),
    description    :: binary() | undefined,
    aggregate_name :: binary() | undefined,
    fields         :: list() | undefined
}).

-export_type([design_event_v1/0]).
-opaque design_event_v1() :: #design_event_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, design_event_v1()} | {error, term()}.
new(#{division_id := DivisionId, event_name := EventName} = Params) ->
    {ok, #design_event_v1{
        division_id = DivisionId,
        event_name = EventName,
        description = maps:get(description, Params, undefined),
        aggregate_name = maps:get(aggregate_name, Params, undefined),
        fields = maps:get(fields, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(design_event_v1()) -> {ok, design_event_v1()} | {error, term()}.
validate(#design_event_v1{division_id = V}) when
    not is_binary(V); byte_size(V) =:= 0 ->
    {error, invalid_division_id};
validate(#design_event_v1{event_name = N}) when
    not is_binary(N); byte_size(N) =:= 0 ->
    {error, invalid_event_name};
validate(#design_event_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(design_event_v1()) -> map().
to_map(#design_event_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"design_event">>,
        <<"division_id">> => Cmd#design_event_v1.division_id,
        <<"event_name">> => Cmd#design_event_v1.event_name,
        <<"description">> => Cmd#design_event_v1.description,
        <<"aggregate_name">> => Cmd#design_event_v1.aggregate_name,
        <<"fields">> => Cmd#design_event_v1.fields
    }.

-spec from_map(map()) -> {ok, design_event_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    EventName = get_value(event_name, Map),
    case {DivisionId, EventName} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            {ok, #design_event_v1{
                division_id = DivisionId,
                event_name = EventName,
                description = get_value(description, Map, undefined),
                aggregate_name = get_value(aggregate_name, Map, undefined),
                fields = get_value(fields, Map, undefined)
            }}
    end.

%% Accessors
-spec get_division_id(design_event_v1()) -> binary().
get_division_id(#design_event_v1{division_id = V}) -> V.

-spec get_event_name(design_event_v1()) -> binary().
get_event_name(#design_event_v1{event_name = V}) -> V.

-spec get_description(design_event_v1()) -> binary() | undefined.
get_description(#design_event_v1{description = V}) -> V.

-spec get_aggregate_name(design_event_v1()) -> binary() | undefined.
get_aggregate_name(#design_event_v1{aggregate_name = V}) -> V.

-spec get_fields(design_event_v1()) -> list() | undefined.
get_fields(#design_event_v1{fields = V}) -> V.

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
