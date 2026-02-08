%%% @doc initiate_cartwheel_v1 command
%%% Initiates a new cartwheel (bounded context) in the Cartwheels domain.
-module(initiate_cartwheel_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_torch_id/1, get_context_name/1, get_description/1]).

-record(initiate_cartwheel_v1, {
    cartwheel_id :: binary(),
    torch_id     :: binary() | undefined,
    context_name :: binary(),
    description  :: binary() | undefined
}).

-export_type([initiate_cartwheel_v1/0]).
-opaque initiate_cartwheel_v1() :: #initiate_cartwheel_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, initiate_cartwheel_v1()} | {error, term()}.
new(#{context_name := Name} = Params) ->
    CartwheelId = maps:get(cartwheel_id, Params, generate_id()),
    {ok, #initiate_cartwheel_v1{
        cartwheel_id = CartwheelId,
        torch_id = maps:get(torch_id, Params, undefined),
        context_name = Name,
        description = maps:get(description, Params, undefined)
    }};
new(#{name := Name} = Params) ->
    %% Backward compat: accept 'name' as alias for 'context_name'
    new(Params#{context_name => Name});
new(_) ->
    {error, missing_required_fields}.

-spec validate(initiate_cartwheel_v1()) -> {ok, initiate_cartwheel_v1()} | {error, term()}.
validate(#initiate_cartwheel_v1{context_name = Name}) when
    not is_binary(Name); byte_size(Name) =:= 0 ->
    {error, invalid_context_name};
validate(#initiate_cartwheel_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(initiate_cartwheel_v1()) -> map().
to_map(#initiate_cartwheel_v1{} = Cmd) ->
    #{
        command_type => <<"initiate_cartwheel">>,
        cartwheel_id => Cmd#initiate_cartwheel_v1.cartwheel_id,
        torch_id => Cmd#initiate_cartwheel_v1.torch_id,
        context_name => Cmd#initiate_cartwheel_v1.context_name,
        description => Cmd#initiate_cartwheel_v1.description
    }.

-spec from_map(map()) -> {ok, initiate_cartwheel_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#initiate_cartwheel_v1{cartwheel_id = V}) -> V.
get_torch_id(#initiate_cartwheel_v1{torch_id = V}) -> V.
get_context_name(#initiate_cartwheel_v1{context_name = V}) -> V.
get_description(#initiate_cartwheel_v1{description = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"cw-", Ts/binary, "-", Rand/binary>>.
