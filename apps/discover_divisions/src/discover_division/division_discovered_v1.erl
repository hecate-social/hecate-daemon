-module(division_discovered_v1).
-export([new/1, from_map/1, to_map/1]).
-export([get_venture_id/1, get_division_id/1, get_context_name/1, get_description/1,
         get_identified_by/1, get_discovered_at/1]).

-record(division_discovered_v1, {
    venture_id :: binary(),
    division_id :: binary(),
    context_name :: binary(),
    description :: binary() | undefined,
    identified_by :: binary() | undefined,
    discovered_at :: non_neg_integer()
}).

new(#{venture_id := VentureId, context_name := ContextName} = Params) ->
    #division_discovered_v1{
        venture_id = VentureId,
        division_id = maps:get(division_id, Params, generate_division_id()),
        context_name = ContextName,
        description = maps:get(description, Params, undefined),
        identified_by = maps:get(identified_by, Params, undefined),
        discovered_at = maps:get(discovered_at, Params, erlang:system_time(millisecond))
    }.

to_map(#division_discovered_v1{venture_id = V, division_id = DI, context_name = CN,
                                description = D, identified_by = IB, discovered_at = DA}) ->
    #{
        <<"event_type">> => <<"division_discovered_v1">>,
        <<"venture_id">> => V,
        <<"division_id">> => DI,
        <<"context_name">> => CN,
        <<"description">> => D,
        <<"identified_by">> => IB,
        <<"discovered_at">> => DA
    }.

from_map(Map) ->
    {ok, #division_discovered_v1{
        venture_id = get_val(venture_id, Map),
        division_id = get_val(division_id, Map),
        context_name = get_val(context_name, Map),
        description = get_val(description, Map),
        identified_by = get_val(identified_by, Map),
        discovered_at = get_val(discovered_at, Map)
    }}.

get_venture_id(#division_discovered_v1{venture_id = V}) -> V.
get_division_id(#division_discovered_v1{division_id = V}) -> V.
get_context_name(#division_discovered_v1{context_name = V}) -> V.
get_description(#division_discovered_v1{description = V}) -> V.
get_identified_by(#division_discovered_v1{identified_by = V}) -> V.
get_discovered_at(#division_discovered_v1{discovered_at = V}) -> V.

generate_division_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"div-", Ts/binary, "-", Rand/binary>>.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
