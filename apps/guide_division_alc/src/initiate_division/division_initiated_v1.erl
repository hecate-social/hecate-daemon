%%% @doc division_initiated_v1 event
%%% Emitted when a division is successfully initiated.
-module(division_initiated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_division_id/1, get_venture_id/1, get_context_name/1,
         get_initiated_by/1, get_initiated_at/1]).

-record(division_initiated_v1, {
    division_id  :: binary(),
    venture_id   :: binary(),
    context_name :: binary(),
    initiated_by :: binary() | undefined,
    initiated_at :: integer()
}).

-export_type([division_initiated_v1/0]).
-opaque division_initiated_v1() :: #division_initiated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> division_initiated_v1().
new(#{division_id := DivisionId, venture_id := VentureId, context_name := ContextName} = Params) ->
    #division_initiated_v1{
        division_id = DivisionId,
        venture_id = VentureId,
        context_name = ContextName,
        initiated_by = maps:get(initiated_by, Params, undefined),
        initiated_at = erlang:system_time(millisecond)
    }.

-spec to_map(division_initiated_v1()) -> map().
to_map(#division_initiated_v1{} = E) ->
    #{
        <<"event_type">> => <<"division_initiated_v1">>,
        <<"division_id">> => E#division_initiated_v1.division_id,
        <<"venture_id">> => E#division_initiated_v1.venture_id,
        <<"context_name">> => E#division_initiated_v1.context_name,
        <<"initiated_by">> => E#division_initiated_v1.initiated_by,
        <<"initiated_at">> => E#division_initiated_v1.initiated_at
    }.

-spec from_map(map()) -> {ok, division_initiated_v1()} | {error, term()}.
from_map(Map) ->
    DivisionId = get_value(division_id, Map),
    VentureId = get_value(venture_id, Map),
    ContextName = get_value(context_name, Map),
    case {DivisionId, VentureId, ContextName} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #division_initiated_v1{
                division_id = DivisionId,
                venture_id = VentureId,
                context_name = ContextName,
                initiated_by = get_value(initiated_by, Map, undefined),
                initiated_at = get_value(initiated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_division_id(division_initiated_v1()) -> binary().
get_division_id(#division_initiated_v1{division_id = V}) -> V.

-spec get_venture_id(division_initiated_v1()) -> binary().
get_venture_id(#division_initiated_v1{venture_id = V}) -> V.

-spec get_context_name(division_initiated_v1()) -> binary().
get_context_name(#division_initiated_v1{context_name = V}) -> V.

-spec get_initiated_by(division_initiated_v1()) -> binary() | undefined.
get_initiated_by(#division_initiated_v1{initiated_by = V}) -> V.

-spec get_initiated_at(division_initiated_v1()) -> integer().
get_initiated_at(#division_initiated_v1{initiated_at = V}) -> V.

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
