-module(aggregate_designed_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_aggregate_id/1, get_aggregate_name/1,
         get_stream_pattern/1, get_status_flags/1, get_description/1,
         get_designed_by/1, get_designed_at/1]).

-record(aggregate_designed_v1, {
    division_id :: binary(),
    aggregate_id :: binary(),
    aggregate_name :: binary(),
    stream_pattern :: binary(),
    status_flags :: [map()],
    description :: binary() | undefined,
    designed_by :: binary() | undefined,
    designed_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, aggregate_name := AggregateName} = Params) ->
    #aggregate_designed_v1{
        division_id = DivisionId,
        aggregate_id = maps:get(aggregate_id, Params, generate_aggregate_id()),
        aggregate_name = AggregateName,
        stream_pattern = maps:get(stream_pattern, Params, <<>>),
        status_flags = maps:get(status_flags, Params, []),
        description = maps:get(description, Params, undefined),
        designed_by = maps:get(designed_by, Params, undefined),
        designed_at = maps:get(designed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#aggregate_designed_v1{division_id = DI, aggregate_id = AI, aggregate_name = AN,
                               stream_pattern = SP, status_flags = SF, description = D,
                               designed_by = DB, designed_at = DA}) ->
    #{
        <<"event_type">> => <<"aggregate_designed_v1">>,
        <<"division_id">> => DI,
        <<"aggregate_id">> => AI,
        <<"aggregate_name">> => AN,
        <<"stream_pattern">> => SP,
        <<"status_flags">> => SF,
        <<"description">> => D,
        <<"designed_by">> => DB,
        <<"designed_at">> => DA
    }.

from_map(Map) ->
    {ok, #aggregate_designed_v1{
        division_id = get_val(division_id, Map),
        aggregate_id = get_val(aggregate_id, Map),
        aggregate_name = get_val(aggregate_name, Map),
        stream_pattern = get_val(stream_pattern, Map),
        status_flags = get_val(status_flags, Map),
        description = get_val(description, Map),
        designed_by = get_val(designed_by, Map),
        designed_at = get_val(designed_at, Map)
    }}.

get_division_id(#aggregate_designed_v1{division_id = V}) -> V.
get_aggregate_id(#aggregate_designed_v1{aggregate_id = V}) -> V.
get_aggregate_name(#aggregate_designed_v1{aggregate_name = V}) -> V.
get_stream_pattern(#aggregate_designed_v1{stream_pattern = V}) -> V.
get_status_flags(#aggregate_designed_v1{status_flags = V}) -> V.
get_description(#aggregate_designed_v1{description = V}) -> V.
get_designed_by(#aggregate_designed_v1{designed_by = V}) -> V.
get_designed_at(#aggregate_designed_v1{designed_at = V}) -> V.

generate_aggregate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"agg-", Ts/binary, "-", Rand/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
