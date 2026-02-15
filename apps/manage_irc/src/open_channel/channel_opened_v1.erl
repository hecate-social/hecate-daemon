%%% @doc channel_opened_v1 event
%%% Emitted when an IRC channel is successfully opened.
-module(channel_opened_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_channel_id/1, get_name/1, get_topic/1, get_opened_by/1, get_opened_at/1]).

-record(channel_opened_v1, {
    channel_id :: binary(),
    name       :: binary(),
    topic      :: binary() | undefined,
    opened_by  :: binary() | undefined,
    opened_at  :: integer()
}).

-export_type([channel_opened_v1/0]).
-opaque channel_opened_v1() :: #channel_opened_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> channel_opened_v1().
new(#{channel_id := ChannelId, name := Name} = Params) ->
    #channel_opened_v1{
        channel_id = ChannelId,
        name = Name,
        topic = maps:get(topic, Params, undefined),
        opened_by = maps:get(opened_by, Params, undefined),
        opened_at = erlang:system_time(millisecond)
    }.

-spec to_map(channel_opened_v1()) -> map().
to_map(#channel_opened_v1{} = E) ->
    #{
        <<"event_type">> => <<"channel_opened_v1">>,
        <<"channel_id">> => E#channel_opened_v1.channel_id,
        <<"name">> => E#channel_opened_v1.name,
        <<"topic">> => E#channel_opened_v1.topic,
        <<"opened_by">> => E#channel_opened_v1.opened_by,
        <<"opened_at">> => E#channel_opened_v1.opened_at
    }.

-spec from_map(map()) -> {ok, channel_opened_v1()} | {error, term()}.
from_map(Map) ->
    ChannelId = get_val(channel_id, Map),
    Name = get_val(name, Map),
    case {ChannelId, Name} of
        {undefined, _} -> {error, invalid_event};
        {_, undefined} -> {error, invalid_event};
        _ ->
            {ok, #channel_opened_v1{
                channel_id = ChannelId,
                name = Name,
                topic = get_val(topic, Map, undefined),
                opened_by = get_val(opened_by, Map, undefined),
                opened_at = get_val(opened_at, Map, erlang:system_time(millisecond))
            }}
    end.

%% Accessors
-spec get_channel_id(channel_opened_v1()) -> binary().
get_channel_id(#channel_opened_v1{channel_id = V}) -> V.

-spec get_name(channel_opened_v1()) -> binary().
get_name(#channel_opened_v1{name = V}) -> V.

-spec get_topic(channel_opened_v1()) -> binary() | undefined.
get_topic(#channel_opened_v1{topic = V}) -> V.

-spec get_opened_by(channel_opened_v1()) -> binary() | undefined.
get_opened_by(#channel_opened_v1{opened_by = V}) -> V.

-spec get_opened_at(channel_opened_v1()) -> integer().
get_opened_at(#channel_opened_v1{opened_at = V}) -> V.

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
