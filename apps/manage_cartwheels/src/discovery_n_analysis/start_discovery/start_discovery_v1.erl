%%% @doc start_discovery_v1 command
%%% Starts the discovery phase for an ALC project.
-module(start_discovery_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1]).

-record(start_discovery_v1, {
    cartwheel_id :: binary()
}).

-export_type([start_discovery_v1/0]).
-opaque start_discovery_v1() :: #start_discovery_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, start_discovery_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId} = _Params) ->
    Cmd = #start_discovery_v1{
        cartwheel_id = CartwheelId
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(start_discovery_v1()) -> {ok, start_discovery_v1()} | {error, term()}.
validate(#start_discovery_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#start_discovery_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(start_discovery_v1()) -> map().
to_map(#start_discovery_v1{} = Cmd) ->
    #{
        command_type => <<"start_discovery">>,
        cartwheel_id => Cmd#start_discovery_v1.cartwheel_id
    }.

-spec from_map(map()) -> {ok, start_discovery_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#start_discovery_v1{cartwheel_id = V}) -> V.
