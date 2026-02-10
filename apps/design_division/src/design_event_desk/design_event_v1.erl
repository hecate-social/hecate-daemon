-module(design_event_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_event_name/1, get_aggregate_name/1,
         get_payload_fields/1, get_description/1, get_designed_by/1]).

-record(design_event_v1, {
    division_id :: binary(),
    event_name :: binary(),
    aggregate_name :: binary(),
    payload_fields :: [map()],
    description :: binary() | undefined,
    designed_by :: binary() | undefined
}).

new(#{division_id := DivisionId, event_name := EventName, aggregate_name := AggregateName} = Params) ->
    Cmd = #design_event_v1{
        division_id = DivisionId,
        event_name = EventName,
        aggregate_name = AggregateName,
        payload_fields = maps:get(payload_fields, Params, []),
        description = maps:get(description, Params, undefined),
        designed_by = maps:get(designed_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#design_event_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#design_event_v1{event_name = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, event_name}};
validate(#design_event_v1{aggregate_name = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, aggregate_name}};
validate(_) -> ok.

to_map(#design_event_v1{division_id = DI, event_name = EN, aggregate_name = AN,
                         payload_fields = PF, description = D, designed_by = DB}) ->
    #{
        <<"command_type">> => <<"design_event">>,
        <<"division_id">> => DI,
        <<"event_name">> => EN,
        <<"aggregate_name">> => AN,
        <<"payload_fields">> => PF,
        <<"description">> => D,
        <<"designed_by">> => DB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    EventName = get_val(event_name, Map),
    AggregateName = get_val(aggregate_name, Map),
    PayloadFields = get_val(payload_fields, Map),
    Description = get_val(description, Map),
    DesignedBy = get_val(designed_by, Map),
    new(#{division_id => DivisionId, event_name => EventName,
          aggregate_name => AggregateName, payload_fields => PayloadFields,
          description => Description, designed_by => DesignedBy}).

get_division_id(#design_event_v1{division_id = V}) -> V.
get_event_name(#design_event_v1{event_name = V}) -> V.
get_aggregate_name(#design_event_v1{aggregate_name = V}) -> V.
get_payload_fields(#design_event_v1{payload_fields = V}) -> V.
get_description(#design_event_v1{description = V}) -> V.
get_designed_by(#design_event_v1{designed_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
