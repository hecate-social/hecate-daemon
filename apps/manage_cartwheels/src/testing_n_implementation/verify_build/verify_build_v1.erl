%%% @doc verify_build_v1 command
%%% Verifies a build during the testing and implementation phase.
-module(verify_build_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_build_id/1, get_result/1, get_notes/1]).

-record(verify_build_v1, {
    cartwheel_id :: binary(),
    build_id   :: binary(),
    result     :: binary(),
    notes      :: binary() | undefined
}).

-export_type([verify_build_v1/0]).
-opaque verify_build_v1() :: #verify_build_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, verify_build_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId} = Params) ->
    Cmd = #verify_build_v1{
        cartwheel_id = CartwheelId,
        build_id = maps:get(build_id, Params, generate_id()),
        result = maps:get(result, Params, <<"pass">>),
        notes = maps:get(notes, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(verify_build_v1()) -> {ok, verify_build_v1()} | {error, term()}.
validate(#verify_build_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#verify_build_v1{result = R}) when
    R =/= <<"pass">>, R =/= <<"fail">> ->
    {error, invalid_result};
validate(#verify_build_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(verify_build_v1()) -> map().
to_map(#verify_build_v1{} = Cmd) ->
    #{
        command_type => <<"verify_build">>,
        cartwheel_id => Cmd#verify_build_v1.cartwheel_id,
        build_id => Cmd#verify_build_v1.build_id,
        result => Cmd#verify_build_v1.result,
        notes => Cmd#verify_build_v1.notes
    }.

-spec from_map(map()) -> {ok, verify_build_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#verify_build_v1{cartwheel_id = V}) -> V.
get_build_id(#verify_build_v1{build_id = V}) -> V.
get_result(#verify_build_v1{result = V}) -> V.
get_notes(#verify_build_v1{notes = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"bld-", Ts/binary, "-", Rand/binary>>.
