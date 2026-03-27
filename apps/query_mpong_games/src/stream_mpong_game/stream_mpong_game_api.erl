%%%-------------------------------------------------------------------
%%% @doc GET /api/mpong/games/:game_id/stream — SSE endpoint for
%%% real-time game state.
%%%
%%% Joins a pg group for LAN delivery and subscribes to mesh topic
%%% for cross-relay delivery. Filters by game_id in payload.
%%% @end
%%%-------------------------------------------------------------------
-module(stream_mpong_game_api).

-export([init/2, routes/0]).

-define(SCOPE, pg).
-define(HEARTBEAT_MS, 5000).

routes() -> [{"/api/mpong/games/:game_id/stream", ?MODULE, []}].

init(Req0, _State) ->
    case cowboy_req:method(Req0) of
        <<"GET">> -> start_stream(Req0);
        _ ->
            Req = cowboy_req:reply(405,
                #{<<"content-type">> => <<"application/json">>},
                json:encode(#{ok => false, error => <<"method_not_allowed">>}),
                Req0),
            {ok, Req, []}
    end.

start_stream(Req0) ->
    GameId = cowboy_req:binding(game_id, Req0),

    ensure_pg_scope(),
    ok = pg:join(?SCOPE, {mpong_game_stream, GameId}, self()),

    %% Subscribe to shared mesh topic, filter by game_id in payload
    Self = self(),
    MeshTopic = broadcast_game_state:topic(),
    case erlang:function_exported(hecate_mesh, subscribe, 2) of
        true ->
            hecate_mesh:subscribe(MeshTopic, fun(Msg) ->
                Payload = case Msg of
                    #{payload := P} -> P;
                    P when is_map(P) -> P;
                    P when is_binary(P) -> json:decode(P)
                end,
                case Payload of
                    #{<<"game_id">> := GID} when GID =:= GameId ->
                        Self ! {mpong_state, GameId, Payload};
                    _ -> ok
                end
            end);
        false -> ok
    end,
    logger:info("[mpong_sse] Joined pg + mesh for game ~s", [GameId]),

    Req = cowboy_req:stream_reply(200, #{
        <<"content-type">> => <<"text/event-stream">>,
        <<"cache-control">> => <<"no-cache">>,
        <<"connection">> => <<"keep-alive">>,
        <<"x-accel-buffering">> => <<"no">>
    }, Req0),

    cowboy_req:stream_body(
        <<"event: connected\ndata: {\"game_id\":\"", GameId/binary, "\"}\n\n">>,
        nofin, Req),

    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
    stream_loop(Req, GameId).

stream_loop(Req, GameId) ->
    receive
        {mpong_state, _GameId, StateMsg} ->
            Data = json:encode(StateMsg),
            case catch cowboy_req:stream_body(
                <<"event: state\ndata: ", Data/binary, "\n\n">>,
                nofin, Req) of
                ok -> stream_loop(Req, GameId);
                _ -> {ok, Req, []}
            end;

        heartbeat ->
            case catch cowboy_req:stream_body(<<": heartbeat\n\n">>, nofin, Req) of
                ok ->
                    erlang:send_after(?HEARTBEAT_MS, self(), heartbeat),
                    stream_loop(Req, GameId);
                _ -> {ok, Req, []}
            end;

        _Other ->
            stream_loop(Req, GameId)
    end.

ensure_pg_scope() ->
    case pg:start(?SCOPE) of
        {ok, _Pid} -> ok;
        {error, {already_started, _Pid}} -> ok
    end.
