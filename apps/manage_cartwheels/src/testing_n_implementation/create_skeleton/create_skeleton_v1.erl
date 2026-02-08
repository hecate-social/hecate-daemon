%%% @doc create_skeleton_v1 command
%%% Creates a skeleton during the testing and implementation phase.
-module(create_skeleton_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_skeleton_id/1, get_description/1]).

-record(create_skeleton_v1, {
    cartwheel_id  :: binary(),
    skeleton_id :: binary(),
    description :: binary() | undefined
}).

-export_type([create_skeleton_v1/0]).
-opaque create_skeleton_v1() :: #create_skeleton_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, create_skeleton_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId} = Params) ->
    Cmd = #create_skeleton_v1{
        cartwheel_id = CartwheelId,
        skeleton_id = maps:get(skeleton_id, Params, generate_id()),
        description = maps:get(description, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(create_skeleton_v1()) -> {ok, create_skeleton_v1()} | {error, term()}.
validate(#create_skeleton_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#create_skeleton_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(create_skeleton_v1()) -> map().
to_map(#create_skeleton_v1{} = Cmd) ->
    #{
        command_type => <<"create_skeleton">>,
        cartwheel_id => Cmd#create_skeleton_v1.cartwheel_id,
        skeleton_id => Cmd#create_skeleton_v1.skeleton_id,
        description => Cmd#create_skeleton_v1.description
    }.

-spec from_map(map()) -> {ok, create_skeleton_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#create_skeleton_v1{cartwheel_id = V}) -> V.
get_skeleton_id(#create_skeleton_v1{skeleton_id = V}) -> V.
get_description(#create_skeleton_v1{description = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"skl-", Ts/binary, "-", Rand/binary>>.
