%%%-------------------------------------------------------------------
%%% @doc POST /api/mpong/host — host a new MPong game.
%%%
%%% Supports quick_start mode: hosts game, adds N AI bots, starts immediately.
%%% Body: {"max_players": N, "quick_start": true, "bot_count": 2}
%%% @end
%%%-------------------------------------------------------------------
-module(host_mpong_game_api).

-export([init/2, routes/0]).

-include_lib("evoq/include/evoq.hrl").

routes() -> [{"/api/mpong/host", ?MODULE, []}].

init(Req0, State) ->
    case cowboy_req:method(Req0) of
        <<"POST">> -> handle_post(Req0, State);
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, State}
    end.

handle_post(Req0, State) ->
    {ok, RawBody, Req1} = cowboy_req:read_body(Req0),
    Body = json:decode(RawBody),
    MaxPlayers = maps:get(<<"max_players">>, Body, 8),
    QuickStart = maps:get(<<"quick_start">>, Body, false),
    BotCount = maps:get(<<"bot_count">>, Body, 2),
    GameId = generate_game_id(),
    HostNodeId = atom_to_binary(node()),

    Cmd = host_game_v1:new(GameId, HostNodeId, MaxPlayers),
    case maybe_host_game:dispatch(Cmd) of
        {ok, _V, _Events} ->
            case QuickStart of
                true ->
                    quick_start(GameId, HostNodeId, BotCount),
                    Resp = json:encode(#{ok => true, game_id => GameId,
                                         host_node_id => HostNodeId,
                                         status => <<"playing">>}),
                    Req = cowboy_req:reply(201,
                        #{<<"content-type">> => <<"application/json">>},
                        Resp, Req1),
                    {ok, Req, State};
                _ ->
                    Resp = json:encode(#{ok => true, game_id => GameId,
                                         host_node_id => HostNodeId}),
                    Req = cowboy_req:reply(201,
                        #{<<"content-type">> => <<"application/json">>},
                        Resp, Req1),
                    {ok, Req, State}
            end;
        {error, Reason} ->
            ErrBin = if is_atom(Reason) -> atom_to_binary(Reason);
                        is_binary(Reason) -> Reason;
                        true -> <<"unknown_error">>
                     end,
            Resp = json:encode(#{ok => false, error => ErrBin}),
            Req = cowboy_req:reply(400,
                #{<<"content-type">> => <<"application/json">>},
                Resp, Req1),
            {ok, Req, State}
    end.

%%====================================================================
%% Internal: Quick start with AI bots
%%====================================================================

quick_start(GameId, HostNodeId, BotCount) ->
    %% Add bots as players (including host)
    BotNames = [bot_name(I) || I <- lists:seq(1, BotCount)],
    lists:foldl(fun(BotName, WallIdx) ->
        dispatch_join(GameId, BotName, WallIdx),
        WallIdx + 1
    end, 0, BotNames),

    %% Small delay for events to propagate
    timer:sleep(100),

    %% Start the game
    dispatch_start(GameId, HostNodeId),

    %% Small delay for start event
    timer:sleep(100),

    %% Start the engine
    PlayersMap = maps:from_list([
        {BotName, #{wall_index => I}}
        || {I, BotName} <- lists:enumerate(0, BotNames)
    ]),
    run_game_engine_sup:start_engine(#{
        game_id => GameId,
        players => PlayersMap
    }).

dispatch_join(GameId, PlayerNodeId, _WallIndex) ->
    StreamId = mpong_game_aggregate:stream_id(GameId),
    EvoqCmd = #evoq_command{
        command_type = join_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => join_game,
            game_id => GameId,
            player_node_id => PlayerNodeId
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

dispatch_start(GameId, HostNodeId) ->
    StreamId = mpong_game_aggregate:stream_id(GameId),
    EvoqCmd = #evoq_command{
        command_type = start_game,
        aggregate_type = mpong_game_aggregate,
        aggregate_id = StreamId,
        payload = #{
            command_type => start_game,
            game_id => GameId,
            host_node_id => HostNodeId
        },
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mpong_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

bot_name(N) ->
    <<"bot_", (integer_to_binary(N))/binary, "@", (atom_to_binary(node()))/binary>>.

generate_game_id() ->
    Rand = crypto:strong_rand_bytes(8),
    binary:encode_hex(Rand, lowercase).
