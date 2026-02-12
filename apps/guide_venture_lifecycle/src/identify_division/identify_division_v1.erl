%%% @doc identify_division_v1 command
%%% Identifies a new division within a venture during discovery.
-module(identify_division_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_division_id/1, get_context_name/1,
         get_description/1, get_identified_by/1]).

-record(identify_division_v1, {
    venture_id   :: binary(),
    division_id  :: binary() | undefined,
    context_name :: binary(),
    description  :: binary() | undefined,
    identified_by :: binary() | undefined
}).

-export_type([identify_division_v1/0]).
-opaque identify_division_v1() :: #identify_division_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, identify_division_v1()} | {error, term()}.
new(#{venture_id := VentureId, context_name := ContextName} = Params) ->
    Cmd = #identify_division_v1{
        venture_id = VentureId,
        division_id = maps:get(division_id, Params, undefined),
        context_name = ContextName,
        description = maps:get(description, Params, undefined),
        identified_by = maps:get(identified_by, Params, undefined)
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(identify_division_v1()) -> ok | {error, term()}.
validate(#identify_division_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#identify_division_v1{context_name = N}) when not is_binary(N); N =:= <<>> ->
    {error, {invalid_field, context_name}};
validate(_) -> ok.

-spec to_map(identify_division_v1()) -> map().
to_map(#identify_division_v1{venture_id = V, division_id = DI, context_name = CN,
                              description = D, identified_by = IB}) ->
    #{
        <<"command_type">> => <<"identify_division">>,
        <<"venture_id">> => V,
        <<"division_id">> => DI,
        <<"context_name">> => CN,
        <<"description">> => D,
        <<"identified_by">> => IB
    }.

-spec from_map(map()) -> {ok, identify_division_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    ContextName = get_value(context_name, Map),
    DivisionId = get_value(division_id, Map),
    Description = get_value(description, Map),
    IdentifiedBy = get_value(identified_by, Map),
    case {VentureId, ContextName} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, division_id => DivisionId,
                  context_name => ContextName, description => Description,
                  identified_by => IdentifiedBy})
    end.

-spec get_venture_id(identify_division_v1()) -> binary().
get_venture_id(#identify_division_v1{venture_id = V}) -> V.

-spec get_division_id(identify_division_v1()) -> binary() | undefined.
get_division_id(#identify_division_v1{division_id = V}) -> V.

-spec get_context_name(identify_division_v1()) -> binary().
get_context_name(#identify_division_v1{context_name = V}) -> V.

-spec get_description(identify_division_v1()) -> binary() | undefined.
get_description(#identify_division_v1{description = V}) -> V.

-spec get_identified_by(identify_division_v1()) -> binary() | undefined.
get_identified_by(#identify_division_v1{identified_by = V}) -> V.

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
