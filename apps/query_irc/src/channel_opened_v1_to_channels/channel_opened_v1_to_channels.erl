%%% @doc Projection: channel_opened_v1 -> channels SQLite table
%%% Subscribes to dev_studio_store, INSERTs new channels.
-module(channel_opened_v1_to_channels).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-include_lib("manage_irc/include/irc_channel_status.hrl").
-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-define(EVENT_TYPE, <<"channel_opened_v1">>).
-define(SUB_NAME, <<"channel_opened_v1_to_channels">>).
-define(STORE_ID, dev_studio_store).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, _} = reckon_evoq_adapter:subscribe(
        ?STORE_ID, event_type, ?EVENT_TYPE, ?SUB_NAME,
        #{subscriber_pid => self()}),
    {ok, #{}}.

handle_info({events, Events}, State) ->
    lists:foreach(fun project/1, Events),
    {noreply, State};
handle_info(_Info, State) -> {noreply, State}.

handle_call(_Req, _From, State) -> {reply, ok, State}.
handle_cast(_Msg, State) -> {noreply, State}.
terminate(_Reason, _State) -> ok.

%% Internal

project(EventMap) ->
    Data = extract_data(EventMap),
    ChannelId = get_val(channel_id, Data),
    Name = get_val(name, Data),
    Topic = get_val(topic, Data),
    OpenedBy = get_val(opened_by, Data),
    OpenedAt = get_val(opened_at, Data, erlang:system_time(millisecond)),
    Status = evoq_bit_flags:set(0, ?IRC_INITIATED),
    StatusLabel = evoq_bit_flags:to_string(Status, ?IRC_FLAG_MAP),

    Sql = "INSERT OR IGNORE INTO channels (channel_id, name, topic, opened_by, status, status_label, opened_at)
           VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7)",
    query_irc_store:execute(Sql, [ChannelId, Name, Topic, OpenedBy, Status, StatusLabel, OpenedAt]).

extract_data(#event{data = D}) -> D;
extract_data(#{data := D}) -> D;
extract_data(#{<<"data">> := D}) -> D;
extract_data(M) -> M.

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
