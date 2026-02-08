%%% @doc activate_cartwheel_v1 command
%%% Activates a cartwheel within a torch.
-module(activate_cartwheel_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_torch_id/1, get_cartwheel_id/1, get_context_name/1]).

-record(activate_cartwheel_v1, {
    torch_id     :: binary(),
    cartwheel_id :: binary(),
    context_name :: binary()
}).

-export_type([activate_cartwheel_v1/0]).
-opaque activate_cartwheel_v1() :: #activate_cartwheel_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, activate_cartwheel_v1()} | {error, term()}.
new(#{torch_id := TorchId, cartwheel_id := CartwheelId, context_name := ContextName}) ->
    {ok, #activate_cartwheel_v1{
        torch_id = TorchId,
        cartwheel_id = CartwheelId,
        context_name = ContextName
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(activate_cartwheel_v1()) -> {ok, activate_cartwheel_v1()} | {error, term()}.
validate(#activate_cartwheel_v1{torch_id = TorchId}) when
    not is_binary(TorchId); byte_size(TorchId) =:= 0 ->
    {error, invalid_torch_id};
validate(#activate_cartwheel_v1{cartwheel_id = CartwheelId}) when
    not is_binary(CartwheelId); byte_size(CartwheelId) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#activate_cartwheel_v1{context_name = ContextName}) when
    not is_binary(ContextName); byte_size(ContextName) =:= 0 ->
    {error, invalid_context_name};
validate(#activate_cartwheel_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(activate_cartwheel_v1()) -> map().
to_map(#activate_cartwheel_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"activate_cartwheel">>,
        <<"torch_id">> => Cmd#activate_cartwheel_v1.torch_id,
        <<"cartwheel_id">> => Cmd#activate_cartwheel_v1.cartwheel_id,
        <<"context_name">> => Cmd#activate_cartwheel_v1.context_name
    }.

-spec from_map(map()) -> {ok, activate_cartwheel_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    CartwheelId = get_value(cartwheel_id, Map),
    ContextName = get_value(context_name, Map),
    case {TorchId, CartwheelId, ContextName} of
        {undefined, _, _} -> {error, missing_torch_id};
        {_, undefined, _} -> {error, missing_cartwheel_id};
        {_, _, undefined} -> {error, missing_context_name};
        _ ->
            {ok, #activate_cartwheel_v1{
                torch_id = TorchId,
                cartwheel_id = CartwheelId,
                context_name = ContextName
            }}
    end.

%% Accessors
-spec get_torch_id(activate_cartwheel_v1()) -> binary().
get_torch_id(#activate_cartwheel_v1{torch_id = V}) -> V.

-spec get_cartwheel_id(activate_cartwheel_v1()) -> binary().
get_cartwheel_id(#activate_cartwheel_v1{cartwheel_id = V}) -> V.

-spec get_context_name(activate_cartwheel_v1()) -> binary().
get_context_name(#activate_cartwheel_v1{context_name = V}) -> V.

%% Internal helper to get value with atom or binary key
get_value(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> undefined
            end
    end.
