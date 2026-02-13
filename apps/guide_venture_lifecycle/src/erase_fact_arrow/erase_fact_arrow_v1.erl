%%% @doc erase_fact_arrow_v1 command
%%% Erases a fact arrow during Big Picture Event Storming.
-module(erase_fact_arrow_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_arrow_id/1]).

-record(erase_fact_arrow_v1, {
    venture_id :: binary(),
    arrow_id   :: binary()
}).

-export_type([erase_fact_arrow_v1/0]).
-opaque erase_fact_arrow_v1() :: #erase_fact_arrow_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, erase_fact_arrow_v1()} | {error, term()}.
new(#{venture_id := VentureId, arrow_id := ArrowId} = _Params) ->
    Cmd = #erase_fact_arrow_v1{
        venture_id = VentureId,
        arrow_id = ArrowId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(erase_fact_arrow_v1()) -> ok | {error, term()}.
validate(#erase_fact_arrow_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#erase_fact_arrow_v1{arrow_id = A}) when not is_binary(A); A =:= <<>> ->
    {error, {invalid_field, arrow_id}};
validate(_) -> ok.

-spec to_map(erase_fact_arrow_v1()) -> map().
to_map(#erase_fact_arrow_v1{venture_id = V, arrow_id = A}) ->
    #{
        <<"command_type">> => <<"erase_fact_arrow">>,
        <<"venture_id">> => V,
        <<"arrow_id">> => A
    }.

-spec from_map(map()) -> {ok, erase_fact_arrow_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    ArrowId = get_value(arrow_id, Map),
    case {VentureId, ArrowId} of
        {undefined, _} -> {error, missing_required_fields};
        {_, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, arrow_id => ArrowId})
    end.

-spec get_venture_id(erase_fact_arrow_v1()) -> binary().
get_venture_id(#erase_fact_arrow_v1{venture_id = V}) -> V.

-spec get_arrow_id(erase_fact_arrow_v1()) -> binary().
get_arrow_id(#erase_fact_arrow_v1{arrow_id = V}) -> V.

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
