%%% @doc stack_event_sticky_v1 command
%%% Stacks an event sticky onto a target sticky during Big Picture Event Storming.
-module(stack_event_sticky_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_sticky_id/1, get_target_sticky_id/1]).

-record(stack_event_sticky_v1, {
    venture_id       :: binary(),
    sticky_id        :: binary(),
    target_sticky_id :: binary()
}).

-export_type([stack_event_sticky_v1/0]).
-opaque stack_event_sticky_v1() :: #stack_event_sticky_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, stack_event_sticky_v1()} | {error, term()}.
new(#{venture_id := VentureId, sticky_id := StickyId, target_sticky_id := TargetStickyId}) ->
    Cmd = #stack_event_sticky_v1{
        venture_id = VentureId,
        sticky_id = StickyId,
        target_sticky_id = TargetStickyId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(stack_event_sticky_v1()) -> ok | {error, term()}.
validate(#stack_event_sticky_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#stack_event_sticky_v1{sticky_id = S}) when not is_binary(S); S =:= <<>> ->
    {error, {invalid_field, sticky_id}};
validate(#stack_event_sticky_v1{target_sticky_id = T}) when not is_binary(T); T =:= <<>> ->
    {error, {invalid_field, target_sticky_id}};
validate(#stack_event_sticky_v1{sticky_id = Same, target_sticky_id = Same}) ->
    {error, cannot_stack_onto_self};
validate(_) -> ok.

-spec to_map(stack_event_sticky_v1()) -> map().
to_map(#stack_event_sticky_v1{venture_id = V, sticky_id = S, target_sticky_id = T}) ->
    #{
        <<"command_type">> => <<"stack_event_sticky">>,
        <<"venture_id">> => V,
        <<"sticky_id">> => S,
        <<"target_sticky_id">> => T
    }.

-spec from_map(map()) -> {ok, stack_event_sticky_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    StickyId = get_value(sticky_id, Map),
    TargetStickyId = get_value(target_sticky_id, Map),
    case {VentureId, StickyId, TargetStickyId} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, sticky_id => StickyId,
                  target_sticky_id => TargetStickyId})
    end.

-spec get_venture_id(stack_event_sticky_v1()) -> binary().
get_venture_id(#stack_event_sticky_v1{venture_id = V}) -> V.

-spec get_sticky_id(stack_event_sticky_v1()) -> binary().
get_sticky_id(#stack_event_sticky_v1{sticky_id = V}) -> V.

-spec get_target_sticky_id(stack_event_sticky_v1()) -> binary().
get_target_sticky_id(#stack_event_sticky_v1{target_sticky_id = V}) -> V.

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
