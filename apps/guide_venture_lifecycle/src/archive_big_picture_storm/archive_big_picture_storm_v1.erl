%%% @doc archive_big_picture_storm_v1 command
%%% Archives a Big Picture Event Storming session for a venture.
-module(archive_big_picture_storm_v1).

-export([new/1, from_map/1, validate/1, to_map/1, get_venture_id/1]).

-record(archive_big_picture_storm_v1, {
    venture_id :: binary()
}).

-export_type([archive_big_picture_storm_v1/0]).
-opaque archive_big_picture_storm_v1() :: #archive_big_picture_storm_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, archive_big_picture_storm_v1()} | {error, term()}.
new(#{venture_id := VentureId}) ->
    Cmd = #archive_big_picture_storm_v1{venture_id = VentureId},
    case validate(Cmd) of
        ok -> {ok, Cmd};
        {error, _} = Err -> Err
    end;
new(_) ->
    {error, missing_required_fields}.

-spec validate(archive_big_picture_storm_v1()) -> ok | {error, term()}.
validate(#archive_big_picture_storm_v1{venture_id = V}) when not is_binary(V); V =:= <<>> ->
    {error, {invalid_field, venture_id}};
validate(_) -> ok.

-spec to_map(archive_big_picture_storm_v1()) -> map().
to_map(#archive_big_picture_storm_v1{venture_id = V}) ->
    #{
        <<"command_type">> => <<"archive_big_picture_storm">>,
        <<"venture_id">> => V
    }.

-spec from_map(map()) -> {ok, archive_big_picture_storm_v1()} | {error, term()}.
from_map(Map) ->
    VentureId = get_value(venture_id, Map),
    case VentureId of
        undefined -> {error, missing_required_fields};
        _ -> new(#{venture_id => VentureId})
    end.

-spec get_venture_id(archive_big_picture_storm_v1()) -> binary().
get_venture_id(#archive_big_picture_storm_v1{venture_id = V}) -> V.

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
