%%% @doc groom_event_stack_v1 command
%%% Grooms a stack by picking a canonical sticky during Big Picture Event Storming.
-module(groom_event_stack_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1, get_stack_id/1, get_canonical_sticky_id/1]).

-record(groom_event_stack_v1, {
    venture_id         :: binary(),
    stack_id           :: binary(),
    canonical_sticky_id :: binary()
}).

-export_type([groom_event_stack_v1/0]).
-opaque groom_event_stack_v1() :: #groom_event_stack_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, groom_event_stack_v1()} | {error, term()}.
new(#{venture_id := VentureId, stack_id := StackId,
      canonical_sticky_id := CanonicalStickyId}) ->
    Cmd = #groom_event_stack_v1{
        venture_id = VentureId,
        stack_id = StackId,
        canonical_sticky_id = CanonicalStickyId
    },
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(groom_event_stack_v1()) -> ok | {error, term()}.
validate(#groom_event_stack_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(#groom_event_stack_v1{stack_id = S}) when not is_binary(S); S =:= <<>> ->
    {error, {invalid_field, stack_id}};
validate(#groom_event_stack_v1{canonical_sticky_id = C}) when not is_binary(C); C =:= <<>> ->
    {error, {invalid_field, canonical_sticky_id}};
validate(_) -> ok.

-spec to_map(groom_event_stack_v1()) -> map().
to_map(#groom_event_stack_v1{venture_id = V, stack_id = S, canonical_sticky_id = C}) ->
    #{
        <<"command_type">> => <<"groom_event_stack">>,
        <<"venture_id">> => V,
        <<"stack_id">> => S,
        <<"canonical_sticky_id">> => C
    }.

-spec from_map(map()) -> {ok, groom_event_stack_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    StackId = get_value(stack_id, Map),
    CanonicalStickyId = get_value(canonical_sticky_id, Map),
    case {VentureId, StackId, CanonicalStickyId} of
        {undefined, _, _} -> {error, missing_required_fields};
        {_, undefined, _} -> {error, missing_required_fields};
        {_, _, undefined} -> {error, missing_required_fields};
        _ ->
            new(#{venture_id => VentureId, stack_id => StackId,
                  canonical_sticky_id => CanonicalStickyId})
    end.

-spec get_venture_id(groom_event_stack_v1()) -> binary().
get_venture_id(#groom_event_stack_v1{venture_id = V}) -> V.

-spec get_stack_id(groom_event_stack_v1()) -> binary().
get_stack_id(#groom_event_stack_v1{stack_id = V}) -> V.

-spec get_canonical_sticky_id(groom_event_stack_v1()) -> binary().
get_canonical_sticky_id(#groom_event_stack_v1{canonical_sticky_id = V}) -> V.

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
