%%% @doc implement_spoke_v1 command
%%% Implements a spoke during the testing and implementation phase.
-module(implement_spoke_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_implementation_id/1, get_spoke_id/1,
         get_implementation_notes/1]).

-record(implement_spoke_v1, {
    cartwheel_id           :: binary(),
    implementation_id    :: binary(),
    spoke_id             :: binary(),
    implementation_notes :: binary() | undefined
}).

-export_type([implement_spoke_v1/0]).
-opaque implement_spoke_v1() :: #implement_spoke_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, implement_spoke_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId, spoke_id := SpokeId} = Params) ->
    Cmd = #implement_spoke_v1{
        cartwheel_id = CartwheelId,
        implementation_id = maps:get(implementation_id, Params, generate_id()),
        spoke_id = SpokeId,
        implementation_notes = maps:get(implementation_notes, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(implement_spoke_v1()) -> {ok, implement_spoke_v1()} | {error, term()}.
validate(#implement_spoke_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#implement_spoke_v1{spoke_id = S}) when
    not is_binary(S); byte_size(S) =:= 0 ->
    {error, invalid_spoke_id};
validate(#implement_spoke_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(implement_spoke_v1()) -> map().
to_map(#implement_spoke_v1{} = Cmd) ->
    #{
        command_type => <<"implement_spoke">>,
        cartwheel_id => Cmd#implement_spoke_v1.cartwheel_id,
        implementation_id => Cmd#implement_spoke_v1.implementation_id,
        spoke_id => Cmd#implement_spoke_v1.spoke_id,
        implementation_notes => Cmd#implement_spoke_v1.implementation_notes
    }.

-spec from_map(map()) -> {ok, implement_spoke_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#implement_spoke_v1{cartwheel_id = V}) -> V.
get_implementation_id(#implement_spoke_v1{implementation_id = V}) -> V.
get_spoke_id(#implement_spoke_v1{spoke_id = V}) -> V.
get_implementation_notes(#implement_spoke_v1{implementation_notes = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"imp-", Ts/binary, "-", Rand/binary>>.
