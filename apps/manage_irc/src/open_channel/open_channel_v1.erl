%%% @doc open_channel_v1 command
%%% Opens a new IRC channel for P2P chat.
-module(open_channel_v1).

-export([new/1, from_map/1, to_map/1]).
-export([get_channel_id/1, get_name/1, get_topic/1, get_opened_by/1]).
-export([generate_id/0]).

-record(open_channel_v1, {
    channel_id :: binary(),
    name       :: binary(),
    topic      :: binary() | undefined,
    opened_by  :: binary() | undefined
}).

-export_type([open_channel_v1/0]).
-opaque open_channel_v1() :: #open_channel_v1{}.

-dialyzer({nowarn_function, [new/1, from_map/1]}).

-spec new(map()) -> {ok, open_channel_v1()} | {error, term()}.
new(#{name := Name} = Params) ->
    ChannelId = maps:get(channel_id, Params, generate_id()),
    {ok, #open_channel_v1{
        channel_id = ChannelId,
        name = Name,
        topic = maps:get(topic, Params, undefined),
        opened_by = maps:get(opened_by, Params, undefined)
    }};
new(_) ->
    {error, missing_required_fields}.

-spec to_map(open_channel_v1()) -> map().
to_map(#open_channel_v1{} = Cmd) ->
    #{
        <<"command_type">> => <<"open_channel">>,
        <<"channel_id">> => Cmd#open_channel_v1.channel_id,
        <<"name">> => Cmd#open_channel_v1.name,
        <<"topic">> => Cmd#open_channel_v1.topic,
        <<"opened_by">> => Cmd#open_channel_v1.opened_by
    }.

-spec from_map(map()) -> {ok, open_channel_v1()} | {error, term()}.
from_map(Map) ->
    Name = get_val(name, Map),
    ChannelId = get_val(channel_id, Map, generate_id()),
    Topic = get_val(topic, Map, undefined),
    OpenedBy = get_val(opened_by, Map, undefined),
    case Name of
        undefined -> {error, missing_required_fields};
        _ ->
            {ok, #open_channel_v1{
                channel_id = ChannelId,
                name = Name,
                topic = Topic,
                opened_by = OpenedBy
            }}
    end.

%% Accessors
-spec get_channel_id(open_channel_v1()) -> binary().
get_channel_id(#open_channel_v1{channel_id = V}) -> V.

-spec get_name(open_channel_v1()) -> binary().
get_name(#open_channel_v1{name = V}) -> V.

-spec get_topic(open_channel_v1()) -> binary() | undefined.
get_topic(#open_channel_v1{topic = V}) -> V.

-spec get_opened_by(open_channel_v1()) -> binary() | undefined.
get_opened_by(#open_channel_v1{opened_by = V}) -> V.

-spec generate_id() -> binary().
generate_id() ->
    Ts = integer_to_binary(erlang:system_time(millisecond)),
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    <<"chan-", Ts/binary, "-", Rand/binary>>.

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
