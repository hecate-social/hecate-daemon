%%% @doc SSE endpoint: GET /api/irc/stream
%%%
%%% Long-lived Server-Sent Events connection for IRC.
%%% One process per connected client.
%%%
%%% On connect: joins `irc_stream` pg group, starts heartbeat timer.
%%% On join_channel: joins pg group {irc_msg, ChannelId}.
%%% On part_channel: leaves pg group {irc_msg, ChannelId}.
%%% On irc_msg: forwards message as SSE data line.
%%% On irc_presence: forwards presence data as SSE.
%%% On disconnect: process dies, pg auto-removes membership.
%%%
%%% Presence: broadcasts heartbeat to mesh and locally every 15 seconds.
%%% @end
-module(stream_irc_api).

-export([init/2, routes/0]).

routes() -> [{"/api/irc/stream", ?MODULE, []}].

-define(SCOPE, pg).
-define(STREAM_GROUP, irc_stream).
-define(HEARTBEAT_MS, 30000).
-define(PRESENCE_MS, 15000).

-record(stream_state, {
    channels = #{} :: #{binary() => true},
    node_id :: binary() | undefined,
    display_name :: binary() | undefined,
    nick :: binary() | undefined
}).

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> ->
            start_stream(Req0, State);
        _ ->
            hecate_api_utils:method_not_allowed(Req0)
    end.

start_stream(Req0, _State) ->
    ensure_pg_scope(),
    pg:join(?SCOPE, ?STREAM_GROUP, self()),
    logger:info("[stream_irc] Client connected, pid=~p", [self()]),

    %% Get identity for presence
    {NodeId, DisplayName} = get_identity(),

    Req1 = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>
    }, Req0),

    cowboy_req:stream_body(<<": connected\n\n">>, nofin, Req1),

    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
    erlang:send_after(?PRESENCE_MS, self(), broadcast_presence),

    SState = #stream_state{
        node_id = NodeId,
        display_name = DisplayName,
        nick = DisplayName
    },
    stream_loop(Req1, SState).

stream_loop(Req, SState) ->
    receive
        %% IRC message from relay
        {irc_msg, ChannelId, Payload} ->
            case maps:is_key(ChannelId, SState#stream_state.channels) of
                true ->
                    JsonPayload = to_json_binary(Payload),
                    send_sse(Req, SState, JsonPayload);
                false ->
                    stream_loop(Req, SState)
            end;

        %% Presence data from irc_presence_relay or local pg broadcast
        {irc_presence, Data} when is_binary(Data) ->
            send_sse(Req, SState, Data);
        {irc_presence, Data} when is_map(Data) ->
            send_sse(Req, SState, to_json_binary(Data));

        %% Join channel
        {join_channel, ChannelId} ->
            pg:join(?SCOPE, {irc_msg, ChannelId}, self()),
            NewChannels = (SState#stream_state.channels)#{ChannelId => true},
            JoinMsg = to_json_binary(#{
                <<"type">> => <<"joined">>,
                <<"channel_id">> => ChannelId
            }),
            case catch cowboy_req:stream_body(
                <<"data: ", JoinMsg/binary, "\n\n">>, nofin, Req
            ) of
                ok ->
                    broadcast_members_changed(ChannelId),
                    stream_loop(Req, SState#stream_state{channels = NewChannels});
                _ -> {ok, Req, []}
            end;

        %% Part channel
        {part_channel, ChannelId} ->
            pg:leave(?SCOPE, {irc_msg, ChannelId}, self()),
            NewChannels = maps:remove(ChannelId, SState#stream_state.channels),
            %% Auto-close empty channels (mIRC semantics: channel dies when last user leaves)
            maybe_close_empty_channel(ChannelId),
            PartMsg = to_json_binary(#{
                <<"type">> => <<"parted">>,
                <<"channel_id">> => ChannelId
            }),
            case catch cowboy_req:stream_body(
                <<"data: ", PartMsg/binary, "\n\n">>, nofin, Req
            ) of
                ok ->
                    broadcast_members_changed(ChannelId),
                    stream_loop(Req, SState#stream_state{channels = NewChannels});
                _ -> {ok, Req, []}
            end;

        %% Heartbeat
        heartbeat ->
            case catch cowboy_req:stream_body(
                <<": heartbeat\n\n">>, nofin, Req
            ) of
                ok ->
                    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
                    stream_loop(Req, SState);
                _ ->
                    {ok, Req, []}
            end;

        %% Presence broadcast timer
        broadcast_presence ->
            PresenceData = make_presence_data(SState),
            %% Publish to mesh for remote peers (fire-and-forget)
            broadcast_presence_to_mesh(PresenceData),
            %% Send own presence directly to this SSE client
            case catch cowboy_req:stream_body(
                <<"data: ", PresenceData/binary, "\n\n">>, nofin, Req
            ) of
                ok ->
                    %% Also broadcast to other local SSE handlers
                    broadcast_presence_to_pg(PresenceData),
                    erlang:send_after(?PRESENCE_MS, self(), broadcast_presence),
                    stream_loop(Req, SState);
                _ ->
                    {ok, Req, []}
            end;

        %% Nick change
        {change_nick, NewNick} ->
            OldNick = SState#stream_state.nick,
            NewState = SState#stream_state{nick = NewNick},
            NickMsg = to_json_binary(#{
                <<"type">> => <<"nick_change">>,
                <<"old_nick">> => OldNick,
                <<"new_nick">> => NewNick
            }),
            case catch cowboy_req:stream_body(
                <<"data: ", NickMsg/binary, "\n\n">>, nofin, Req
            ) of
                ok -> stream_loop(Req, NewState);
                _ -> {ok, Req, []}
            end;

        %% Info request (from get_channel_members_api)
        {get_info, {From, Ref}} ->
            Info = #{
                <<"node_id">> => SState#stream_state.node_id,
                <<"nick">> => SState#stream_state.nick,
                <<"online">> => true
            },
            From ! {stream_info, Ref, Info},
            stream_loop(Req, SState);

        %% Members changed notification
        {irc_members_changed, ChannelId} ->
            case maps:is_key(ChannelId, SState#stream_state.channels) of
                true ->
                    Msg = to_json_binary(#{
                        <<"type">> => <<"members_changed">>,
                        <<"channel_id">> => ChannelId
                    }),
                    send_sse(Req, SState, Msg);
                false ->
                    stream_loop(Req, SState)
            end;

        _Other ->
            stream_loop(Req, SState)
    end.

%% --- SSE helpers ---

send_sse(Req, SState, JsonBinary) ->
    case catch cowboy_req:stream_body(
        <<"data: ", JsonBinary/binary, "\n\n">>, nofin, Req
    ) of
        ok -> stream_loop(Req, SState);
        _ -> {ok, Req, []}
    end.

%% json:encode returns iodata() in OTP 27+, must convert to binary for /binary
to_json_binary(Map) ->
    iolist_to_binary(json:encode(Map)).

%% --- Members changed broadcast ---

broadcast_members_changed(ChannelId) ->
    Members = pg:get_members(?SCOPE, {irc_msg, ChannelId}),
    lists:foreach(fun(Pid) ->
        Pid ! {irc_members_changed, ChannelId}
    end, Members).

%% --- Presence ---

make_presence_data(#stream_state{node_id = NodeId, nick = Nick}) ->
    to_json_binary(#{
        <<"type">> => <<"presence">>,
        <<"node_id">> => NodeId,
        <<"display_name">> => Nick,
        <<"timestamp">> => erlang:system_time(millisecond)
    }).

broadcast_presence_to_mesh(PresenceData) ->
    hecate_mesh_client:publish(<<"hecate.irc.presence">>, PresenceData).

broadcast_presence_to_pg(PresenceData) ->
    Members = pg:get_members(?SCOPE, ?STREAM_GROUP),
    Self = self(),
    lists:foreach(fun(Pid) ->
        case Pid of
            Self -> ok;
            _ -> Pid ! {irc_presence, PresenceData}
        end
    end, Members).

%% --- Identity ---

get_identity() ->
    try
        case hecate_identity:get_mri() of
            {ok, Mri} ->
                Nick = extract_nick(Mri),
                {Mri, Nick};
            not_initialized ->
                default_identity()
        end
    catch
        _:_ -> default_identity()
    end.

extract_nick(Mri) when is_binary(Mri) ->
    case binary:split(Mri, <<"/">>, [global]) of
        Parts when length(Parts) > 0 ->
            lists:last(Parts);
        _ ->
            Mri
    end.

default_identity() ->
    Rand = binary:encode_hex(crypto:strong_rand_bytes(4)),
    NodeId = <<"anon-", Rand/binary>>,
    {NodeId, NodeId}.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.

%% --- Auto-cleanup ---

%% Close channel when the last member leaves (mIRC semantics).
maybe_close_empty_channel(ChannelId) ->
    case pg:get_members(?SCOPE, {irc_msg, ChannelId}) of
        [] ->
            logger:info("[stream_irc] Channel ~s is empty, closing", [ChannelId]),
            case close_channel_v1:new(#{channel_id => ChannelId, closed_by => <<"auto">>}) of
                {ok, Cmd} -> maybe_close_channel:dispatch(Cmd);
                _ -> ok
            end;
        _ ->
            ok
    end.
