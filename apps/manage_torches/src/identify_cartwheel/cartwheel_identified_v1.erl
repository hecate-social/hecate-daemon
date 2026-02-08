%%% @doc cartwheel_identified_v1 event
%%%
%%% Emitted when a torch identifies a cartwheel (bounded context) it needs.
%%% This event is stored in the TORCH's event stream (not cartwheel's).
%%% It is also published to mesh for the cartwheel service to react.
%%%
%%% Pattern: Parent (torch) IDENTIFIES children, child (cartwheel) INITIATES itself.
%%% @end
-module(cartwheel_identified_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_torch_id/1, get_cartwheel_id/1, get_context_name/1,
         get_description/1, get_identified_by/1, get_identified_at/1]).

-record(cartwheel_identified_v1, {
    torch_id      :: binary(),
    cartwheel_id  :: binary(),
    context_name  :: binary(),
    description   :: binary() | undefined,
    identified_by :: binary() | undefined,
    identified_at :: non_neg_integer()
}).

-export_type([cartwheel_identified_v1/0]).
-opaque cartwheel_identified_v1() :: #cartwheel_identified_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, cartwheel_identified_v1()} | {error, term()}.
new(#{torch_id := TorchId, context_name := ContextName} = Params) ->
    CartwheelId = maps:get(cartwheel_id, Params, identify_cartwheel_v1:generate_cartwheel_id()),
    {ok, #cartwheel_identified_v1{
        torch_id = TorchId,
        cartwheel_id = CartwheelId,
        context_name = ContextName,
        description = maps:get(description, Params, undefined),
        identified_by = maps:get(identified_by, Params, undefined),
        identified_at = maps:get(identified_at, Params, erlang:system_time(millisecond))
    }};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(cartwheel_identified_v1()) -> map().
to_map(#cartwheel_identified_v1{} = E) ->
    #{
        <<"event_type">> => <<"cartwheel_identified_v1">>,
        <<"torch_id">> => E#cartwheel_identified_v1.torch_id,
        <<"cartwheel_id">> => E#cartwheel_identified_v1.cartwheel_id,
        <<"context_name">> => E#cartwheel_identified_v1.context_name,
        <<"description">> => E#cartwheel_identified_v1.description,
        <<"identified_by">> => E#cartwheel_identified_v1.identified_by,
        <<"identified_at">> => E#cartwheel_identified_v1.identified_at
    }.

-spec from_map(map()) -> {ok, cartwheel_identified_v1()} | {error, term()}.
from_map(Map) ->
    TorchId = get_value(torch_id, Map),
    CartwheelId = get_value(cartwheel_id, Map),
    ContextName = get_value(context_name, Map),
    case {TorchId, CartwheelId, ContextName} of
        {undefined, _, _} -> {error, missing_torch_id};
        {_, undefined, _} -> {error, missing_cartwheel_id};
        {_, _, undefined} -> {error, missing_context_name};
        _ ->
            {ok, #cartwheel_identified_v1{
                torch_id = TorchId,
                cartwheel_id = CartwheelId,
                context_name = ContextName,
                description = get_value(description, Map, undefined),
                identified_by = get_value(identified_by, Map, undefined),
                identified_at = get_value(identified_at, Map, 0)
            }}
    end.

%% Accessors
-spec get_torch_id(cartwheel_identified_v1()) -> binary().
get_torch_id(#cartwheel_identified_v1{torch_id = V}) -> V.

-spec get_cartwheel_id(cartwheel_identified_v1()) -> binary().
get_cartwheel_id(#cartwheel_identified_v1{cartwheel_id = V}) -> V.

-spec get_context_name(cartwheel_identified_v1()) -> binary().
get_context_name(#cartwheel_identified_v1{context_name = V}) -> V.

-spec get_description(cartwheel_identified_v1()) -> binary() | undefined.
get_description(#cartwheel_identified_v1{description = V}) -> V.

-spec get_identified_by(cartwheel_identified_v1()) -> binary() | undefined.
get_identified_by(#cartwheel_identified_v1{identified_by = V}) -> V.

-spec get_identified_at(cartwheel_identified_v1()) -> non_neg_integer().
get_identified_at(#cartwheel_identified_v1{identified_at = V}) -> V.

%% Internal helper
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
