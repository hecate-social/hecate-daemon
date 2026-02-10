-module(design_aggregate_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_division_id/1, get_aggregate_name/1, get_stream_pattern/1,
         get_status_flags/1, get_description/1, get_designed_by/1]).

-record(design_aggregate_v1, {
    division_id :: binary(),
    aggregate_name :: binary(),
    stream_pattern :: binary(),
    status_flags :: [map()],
    description :: binary() | undefined,
    designed_by :: binary() | undefined
}).

new(#{division_id := DivisionId, aggregate_name := AggregateName} = Params) ->
    Cmd = #design_aggregate_v1{
        division_id = DivisionId,
        aggregate_name = AggregateName,
        stream_pattern = maps:get(stream_pattern, Params, <<>>),
        status_flags = maps:get(status_flags, Params, []),
        description = maps:get(description, Params, undefined),
        designed_by = maps:get(designed_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#design_aggregate_v1{division_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, division_id}};
validate(#design_aggregate_v1{aggregate_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, aggregate_name}};
validate(_) -> ok.

to_map(#design_aggregate_v1{division_id = DI, aggregate_name = AN, stream_pattern = SP,
                             status_flags = SF, description = D, designed_by = DB}) ->
    #{
        <<"command_type">> => <<"design_aggregate">>,
        <<"division_id">> => DI,
        <<"aggregate_name">> => AN,
        <<"stream_pattern">> => SP,
        <<"status_flags">> => SF,
        <<"description">> => D,
        <<"designed_by">> => DB
    }.

from_map(Map) ->
    DivisionId = get_val(division_id, Map),
    AggregateName = get_val(aggregate_name, Map),
    StreamPattern = get_val(stream_pattern, Map),
    StatusFlags = get_val(status_flags, Map),
    Description = get_val(description, Map),
    DesignedBy = get_val(designed_by, Map),
    new(#{division_id => DivisionId, aggregate_name => AggregateName,
          stream_pattern => StreamPattern, status_flags => StatusFlags,
          description => Description, designed_by => DesignedBy}).

get_division_id(#design_aggregate_v1{division_id = V}) -> V.
get_aggregate_name(#design_aggregate_v1{aggregate_name = V}) -> V.
get_stream_pattern(#design_aggregate_v1{stream_pattern = V}) -> V.
get_status_flags(#design_aggregate_v1{status_flags = V}) -> V.
get_description(#design_aggregate_v1{description = V}) -> V.
get_designed_by(#design_aggregate_v1{designed_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
