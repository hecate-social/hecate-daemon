-module(discover_division_v1).
-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_context_name/1, get_description/1, get_identified_by/1]).

-record(discover_division_v1, {
    venture_id :: binary(),
    context_name :: binary(),
    description :: binary() | undefined,
    identified_by :: binary() | undefined
}).

new(#{venture_id := VentureId, context_name := ContextName} = Params) ->
    Cmd = #discover_division_v1{
        venture_id = VentureId,
        context_name = ContextName,
        description = maps:get(description, Params, undefined),
        identified_by = maps:get(identified_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end.

validate(#discover_division_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#discover_division_v1{context_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, context_name}};
validate(_) -> ok.

to_map(#discover_division_v1{venture_id = V, context_name = CN, description = D, identified_by = IB}) ->
    #{
        <<"command_type">> => <<"discover_division">>,
        <<"venture_id">> => V,
        <<"context_name">> => CN,
        <<"description">> => D,
        <<"identified_by">> => IB
    }.

from_map(Map) ->
    VentureId = get_val(venture_id, Map),
    ContextName = get_val(context_name, Map),
    Description = get_val(description, Map),
    IdentifiedBy = get_val(identified_by, Map),
    new(#{venture_id => VentureId, context_name => ContextName,
          description => Description, identified_by => IdentifiedBy}).

get_venture_id(#discover_division_v1{venture_id = V}) -> V.
get_context_name(#discover_division_v1{context_name = V}) -> V.
get_description(#discover_division_v1{description = V}) -> V.
get_identified_by(#discover_division_v1{identified_by = V}) -> V.

get_val(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.
