%%% @doc submit_vision_v1 command
%%% Marks venture vision as finalized.
-module(submit_vision_v1).

-export([new/1, from_map/1, validate/1, to_map/1]).
-export([get_venture_id/1]).

-record(submit_vision_v1, {
    venture_id :: binary()
}).

-export_type([submit_vision_v1/0]).
-opaque submit_vision_v1() :: #submit_vision_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, submit_vision_v1()} | {error, term()}.
new(#{venture_id := VentureId}) ->
    {ok, #submit_vision_v1{
        venture_id = VentureId
    }};
new(_) ->
    {error, missing_required_fields}.

-spec validate(submit_vision_v1()) -> {ok, submit_vision_v1()} | {error, term()}.
validate(#submit_vision_v1{venture_id = VentureId}) when
    not is_binary(VentureId); byte_size(VentureId) =:= 0 ->
    {error, invalid_venture_id};
validate(#submit_vision_v1{} = Cmd) ->
    {ok, Cmd}.

-spec to_map(submit_vision_v1()) -> map().
to_map(#submit_vision_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"submit_vision">>,
        <<"venture_id">> => Cmd#submit_vision_v1.venture_id
    }.

-spec from_map(map()) -> {ok, submit_vision_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #submit_vision_v1{
                venture_id = VentureId
            }}
    end.

%% Accessors
-spec get_venture_id(submit_vision_v1()) -> binary().
get_venture_id(#submit_vision_v1{venture_id = V}) -> V.

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
