-module(event_designed_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_division_id/1, get_event_id/1, get_event_name/1, get_aggregate_name/1,
         get_payload_fields/1, get_description/1, get_designed_by/1, get_designed_at/1]).

-record(event_designed_v1, {
    division_id :: binary(),
    event_id :: binary(),
    event_name :: binary(),
    aggregate_name :: binary(),
    payload_fields :: [map()],
    description :: binary() | undefined,
    designed_by :: binary() | undefined,
    designed_at :: non_neg_integer()
}).

new(#{division_id := DivisionId, event_name := EventName} = Params) ->
    #event_designed_v1{
        division_id = DivisionId,
        event_id = maps:get(event_id, Params, generate_event_id(DivisionId, EventName)),
        event_name = EventName,
        aggregate_name = maps:get(aggregate_name, Params, undefined),
        payload_fields = maps:get(payload_fields, Params, []),
        description = maps:get(description, Params, undefined),
        designed_by = maps:get(designed_by, Params, undefined),
        designed_at = maps:get(designed_at, Params, erlang:system_time(millisecond))
    }.

to_map(#event_designed_v1{division_id = DI, event_id = EI, event_name = EN,
                           aggregate_name = AN, payload_fields = PF,
                           description = D, designed_by = DB, designed_at = DA}) ->
    #{
        <<"event_type">> => <<"event_designed_v1">>,
        <<"division_id">> => DI,
        <<"event_id">> => EI,
        <<"event_name">> => EN,
        <<"aggregate_name">> => AN,
        <<"payload_fields">> => PF,
        <<"description">> => D,
        <<"designed_by">> => DB,
        <<"designed_at">> => DA
    }.

from_map(Map) ->
    {ok, #event_designed_v1{
        division_id = get_val(division_id, Map),
        event_id = get_val(event_id, Map),
        event_name = get_val(event_name, Map),
        aggregate_name = get_val(aggregate_name, Map),
        payload_fields = get_val(payload_fields, Map),
        description = get_val(description, Map),
        designed_by = get_val(designed_by, Map),
        designed_at = get_val(designed_at, Map)
    }}.

get_division_id(#event_designed_v1{division_id = V}) -> V.
get_event_id(#event_designed_v1{event_id = V}) -> V.
get_event_name(#event_designed_v1{event_name = V}) -> V.
get_aggregate_name(#event_designed_v1{aggregate_name = V}) -> V.
get_payload_fields(#event_designed_v1{payload_fields = V}) -> V.
get_description(#event_designed_v1{description = V}) -> V.
get_designed_by(#event_designed_v1{designed_by = V}) -> V.
get_designed_at(#event_designed_v1{designed_at = V}) -> V.

generate_event_id(DivisionId, EventName) ->
    Timestamp = integer_to_binary(erlang:system_time(millisecond)),
    Hash = crypto:hash(sha256, <<DivisionId/binary, EventName/binary>>),
    ShortHash = binary:part(binary:encode_hex(Hash), 0, 8),
    <<"evt-", Timestamp/binary, "-", ShortHash/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
