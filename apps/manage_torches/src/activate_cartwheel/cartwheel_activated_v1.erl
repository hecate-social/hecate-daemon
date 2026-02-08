%%% @doc cartwheel_activated_v1 event
%%% Emitted when a cartwheel is activated within a torch.
-module(cartwheel_activated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_torch_id/1, get_cartwheel_id/1, get_context_name/1, get_activated_at/1]).

-record(cartwheel_activated_v1, {
    torch_id     :: binary(),
    cartwheel_id :: binary(),
    context_name :: binary(),
    activated_at :: integer()
}).

-export_type([cartwheel_activated_v1/0]).
-opaque cartwheel_activated_v1() :: #cartwheel_activated_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> cartwheel_activated_v1().
new(#{torch_id := TorchId, cartwheel_id := CartwheelId, context_name := ContextName}) ->
    #cartwheel_activated_v1{
        torch_id = TorchId,
        cartwheel_id = CartwheelId,
        context_name = ContextName,
        activated_at = erlang:system_time(millisecond)
    }.

-spec to_map(cartwheel_activated_v1()) -> map().
to_map(#cartwheel_activated_v1{} = E) ->
    #{
        <<"event_type">> => <<"cartwheel_activated_v1">>,
        <<"torch_id">> => E#cartwheel_activated_v1.torch_id,
        <<"cartwheel_id">> => E#cartwheel_activated_v1.cartwheel_id,
        <<"context_name">> => E#cartwheel_activated_v1.context_name,
        <<"activated_at">> => E#cartwheel_activated_v1.activated_at
    }.

-spec from_map(map()) -> {ok, cartwheel_activated_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    CartwheelId = get_value(cartwheel_id, Map),
    ContextName = get_value(context_name, Map),
    case {TorchId, CartwheelId, ContextName} of
        {undefined, _, _} -> {error, invalid_event};
        {_, undefined, _} -> {error, invalid_event};
        {_, _, undefined} -> {error, invalid_event};
        _ ->
            {ok, #cartwheel_activated_v1{
                torch_id = TorchId,
                cartwheel_id = CartwheelId,
                context_name = ContextName,
                activated_at = get_value(activated_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_torch_id(cartwheel_activated_v1()) -> binary().
get_torch_id(#cartwheel_activated_v1{torch_id = V}) -> V.

-spec get_cartwheel_id(cartwheel_activated_v1()) -> binary().
get_cartwheel_id(#cartwheel_activated_v1{cartwheel_id = V}) -> V.

-spec get_context_name(cartwheel_activated_v1()) -> binary().
get_context_name(#cartwheel_activated_v1{context_name = V}) -> V.

-spec get_activated_at(cartwheel_activated_v1()) -> integer().
get_activated_at(#cartwheel_activated_v1{activated_at = V}) -> V.

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
