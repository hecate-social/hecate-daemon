%%% @doc close_channel_v1 command
%%% Closes an IRC channel (walking skeleton archive).
-module(close_channel_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_channel_id/1, get_closed_by/1]).

-record(close_channel_v1, {
    channel_id :: binary(),
    closed_by  :: binary() | undefined
}).

-export_type([close_channel_v1/0]).
-opaque close_channel_v1() :: #close_channel_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, close_channel_v1()} | {error, term()}.
new(#{channel_id := ChannelId} = Params) ->
    {ok, #close_channel_v1{
        channel_id = ChannelId,
        closed_by = maps:get(closed_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(close_channel_v1()) -> map().
to_map(#close_channel_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"close_channel">>,
        <<"channel_id">> => Cmd#close_channel_v1.channel_id,
        <<"closed_by">> => Cmd#close_channel_v1.closed_by
    }.

-spec from_map(map()) -> {ok, close_channel_v1()} | {error, term()}.
from_map(Map) ->
    ChannelId = get_val(channel_id, Map),
    ClosedBy = get_val(closed_by, Map, undefined),
    case ChannelId of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #close_channel_v1{
                channel_id = ChannelId,
                closed_by = ClosedBy
            }}
    end.

%% Accessors
-spec get_channel_id(close_channel_v1()) -> binary().
get_channel_id(#close_channel_v1{channel_id = V}) -> V.

-spec get_closed_by(close_channel_v1()) -> binary() | undefined.
get_closed_by(#close_channel_v1{closed_by = V}) -> V.

%% Internal
get_val(Key, Map) -> get_val(Key, Map, undefined).
get_val(Key, Map, Default) when is_atom(Key) ->
    BinKey = atom_to_binary(Key, utf8),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            case maps:find(BinKey, Map) of
                {ok, V} -> V;
                error -> Default
            end
    end.
