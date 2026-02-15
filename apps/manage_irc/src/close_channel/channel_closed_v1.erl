%%% @doc channel_closed_v1 event
%%% Emitted when an IRC channel is closed.
-module(channel_closed_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_channel_id/1, get_closed_by/1, get_closed_at/1]).

-record(channel_closed_v1, {
    channel_id :: binary(),
    closed_by  :: binary() | undefined,
    closed_at  :: integer()
}).

-export_type([channel_closed_v1/0]).
-opaque channel_closed_v1() :: #channel_closed_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> channel_closed_v1().
new(#{channel_id := ChannelId} = Params) ->
    #channel_closed_v1{
        channel_id = ChannelId,
        closed_by = maps:get(closed_by, Params, undefined),
        closed_at = erlang:system_time(millisecond)
    }.

-spec to_map(channel_closed_v1()) -> map().
to_map(#channel_closed_v1{} = E) ->
    #{
        <<"event_type">> => <<"channel_closed_v1">>,
        <<"channel_id">> => E#channel_closed_v1.channel_id,
        <<"closed_by">> => E#channel_closed_v1.closed_by,
        <<"closed_at">> => E#channel_closed_v1.closed_at
    }.

-spec from_map(map()) -> {ok, channel_closed_v1()} | {error, term()}.
from_map(Map) ->
    ChannelId = get_val(channel_id, Map),
    case ChannelId of
        undefined -> {error, invalid_event};
        _ ->
            {ok, #channel_closed_v1{
                channel_id = ChannelId,
                closed_by = get_val(closed_by, Map, undefined),
                closed_at = get_val(closed_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_channel_id(channel_closed_v1()) -> binary().
get_channel_id(#channel_closed_v1{channel_id = V}) -> V.

-spec get_closed_by(channel_closed_v1()) -> binary() | undefined.
get_closed_by(#channel_closed_v1{closed_by = V}) -> V.

-spec get_closed_at(channel_closed_v1()) -> integer().
get_closed_at(#channel_closed_v1{closed_at = V}) -> V.

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
