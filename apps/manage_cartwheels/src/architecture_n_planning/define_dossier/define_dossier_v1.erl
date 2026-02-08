%%% @doc define_dossier_v1 command
%%% Defines a dossier within the architecture and planning phase.
-module(define_dossier_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_cartwheel_id/1, get_dossier_id/1, get_dossier_name/1,
         get_stream_pattern/1, get_description/1]).

-record(define_dossier_v1, {
    cartwheel_id     :: binary(),
    dossier_id     :: binary(),
    dossier_name   :: binary(),
    stream_pattern :: binary(),
    description    :: binary() | undefined
}).

-export_type([define_dossier_v1/0]).
-opaque define_dossier_v1() :: #define_dossier_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, define_dossier_v1()} | {error, term()}.
new(#{cartwheel_id := CartwheelId, dossier_name := DossierName} = Params) ->
    Cmd = #define_dossier_v1{
        cartwheel_id = CartwheelId,
        dossier_id = maps:get(dossier_id, Params, generate_id()),
        dossier_name = DossierName,
        stream_pattern = maps:get(stream_pattern, Params, <<"default">>),
        description = maps:get(description, Params, undefined)
    },
    validate(Cmd);
new(_) ->
    {error, missing_required_fields}.

-spec validate(define_dossier_v1()) -> {ok, define_dossier_v1()} | {error, term()}.
validate(#define_dossier_v1{cartwheel_id = P}) when
    not is_binary(P); byte_size(P) =:= 0 ->
    {error, invalid_cartwheel_id};
validate(#define_dossier_v1{dossier_name = N}) when
    not is_binary(N); byte_size(N) =:= 0 ->
    {error, invalid_dossier_name};
validate(#define_dossier_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(define_dossier_v1()) -> map().
to_map(#define_dossier_v1{} = Cmd) ->
    #{
        command_type => <<"define_dossier">>,
        cartwheel_id => Cmd#define_dossier_v1.cartwheel_id,
        dossier_id => Cmd#define_dossier_v1.dossier_id,
        dossier_name => Cmd#define_dossier_v1.dossier_name,
        stream_pattern => Cmd#define_dossier_v1.stream_pattern,
        description => Cmd#define_dossier_v1.description
    }.

-spec from_map(map()) -> {ok, define_dossier_v1()} | {error, term()}.
from_map(Map) ->
    new(Map).

%% Accessors
get_cartwheel_id(#define_dossier_v1{cartwheel_id = V}) -> V.
get_dossier_id(#define_dossier_v1{dossier_id = V}) -> V.
get_dossier_name(#define_dossier_v1{dossier_name = V}) -> V.
get_stream_pattern(#define_dossier_v1{stream_pattern = V}) -> V.
get_description(#define_dossier_v1{description = V}) -> V.

%% Internal
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(8)),
    <<"dos-", Ts/binary, "-", Rand/binary>>.
