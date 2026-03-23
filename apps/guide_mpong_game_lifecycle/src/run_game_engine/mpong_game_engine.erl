%%%-------------------------------------------------------------------
%%% @doc MPong game engine — real-time game loop.
%%%
%%% Integer grid 1000x1000. 25Hz tick rate.
%%% Scoring: ping-pong rules (game to 11, win by 2, best of 3).
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_game_engine).
-behaviour(gen_server).

-export([start_link/1]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).
-export([update_paddle/3]).

-define(TICK_HZ, 25).
-define(TICK_MS, 1000 div ?TICK_HZ).
-define(COUNTDOWN_TICKS, 50).    %% 2s pause between points
-define(GAME_POINT, 11).         %% points to win a game
-define(BEST_OF, 3).             %% games in a match

-record(engine, {
    game_id    :: binary(),
    ball       :: mpong_ball:ball(),
    paddles    :: #{integer() => integer()},
    players    :: #{binary() => integer()},   %% node_id => wall_index
    alive      :: #{integer() => boolean()},
    player_modes :: #{integer() => {bot, map()} | remote},  %% wall_index => mode
    %% Obstacles
    obstacles  :: term(),
    %% Scoring
    points     :: #{integer() => integer()},  %% wall_index => points this game
    games_won  :: #{integer() => integer()},  %% wall_index => games won
    serving    :: integer(),                  %% wall_index of server
    total_pts  :: integer(),                  %% total points in current game (for serve rotation)
    %% State
    tick       :: non_neg_integer(),
    paused_until :: non_neg_integer(),        %% tick at which play resumes (point pause)
    timer      :: reference() | undefined
}).

%%====================================================================
%% API
%%====================================================================

start_link(GameConfig) ->
    gen_server:start_link(?MODULE, GameConfig, []).

update_paddle(Pid, NodeId, Position) ->
    gen_server:cast(Pid, {paddle, NodeId, round(Position)}).

%%====================================================================
%% gen_server
%%====================================================================

init(#{game_id := GameId, players := Players} = Config) ->
    {PlayerMap, Paddles, Alive} =
        maps:fold(fun(NodeId, #{wall_index := WI}, {PM, Pa, Al}) ->
            {PM#{NodeId => WI}, Pa#{WI => 500}, Al#{WI => true}}
        end, {#{}, #{}, #{}}, Players),

    %% Player modes: from lobby config or default all to bot with random personality
    PlayerModes = case maps:find(player_modes, Config) of
        {ok, Modes} -> Modes;
        error ->
            %% Legacy: assign fresh random personalities via persistent_term
            maps:foreach(fun(_NodeId, #{wall_index := WI}) ->
                persistent_term:erase({mpong_personality, WI})
            end, Players),
            maps:from_list([{WI, {bot, #{}}} || WI <- maps:values(PlayerMap)])
    end,

    %% Register in pg for cross-node discovery and state broadcast
    ensure_pg(),
    pg:join(pg, {mpong_engine, GameId}, self()),
    pg:join(pg, mpong_games_available, self()),
    pg:join(pg, {mpong_game, GameId}, self()),

    Timer = erlang:send_after(?TICK_MS, self(), tick),

    %% Log champion names
    ChampionNames = [begin
        #{wall_index := WI} = maps:get(NId, Players),
        case maps:get(WI, PlayerModes, {bot, #{}}) of
            {bot, P} -> io_lib:format("~s(~s)", [NId, maps:get(style, P, <<"bot">>)]);
            remote -> io_lib:format("~s(remote)", [NId])
        end
    end || NId <- maps:keys(Players)],
    logger:info("[mpong] Engine started for ~s: ~s", [GameId, lists:join(" vs ", ChampionNames)]),

    {ok, #engine{
        game_id = GameId,
        ball = mpong_ball:new(),
        paddles = Paddles,
        players = PlayerMap,
        alive = Alive,
        player_modes = PlayerModes,
        obstacles = mpong_obstacles:new(),
        points = #{0 => 0, 1 => 0},
        games_won = #{0 => 0, 1 => 0},
        serving = 0,
        total_pts = 0,
        tick = 0,
        paused_until = ?COUNTDOWN_TICKS,
        timer = Timer
    }}.

handle_call(get_game_info, _From, #engine{game_id = GId, players = P,
                                           player_modes = PM, alive = Al} = State) ->
    Info = #{game_id => GId, player_count => maps:size(P),
             player_modes => PM, alive => Al},
    {reply, Info, State};
handle_call(_Req, _From, State) -> {reply, ok, State}.

handle_cast({paddle, NodeId, Position}, #engine{players = Players, paddles = Paddles} = State) ->
    case maps:find(NodeId, Players) of
        {ok, WI} -> {noreply, State#engine{paddles = Paddles#{WI => Position}}};
        error -> {noreply, State}
    end;
handle_cast(_, State) -> {noreply, State}.

handle_info(tick, #engine{tick = Tick, paused_until = PausedUntil} = State0) ->
    %% Always run AI and broadcast
    State1 = run_ai(State0),

    %% Only move ball when not paused
    State2 = case Tick >= PausedUntil of
        true -> step(State1);
        false -> State1
    end,

    broadcast(State2),

    %% Check match over
    case check_match_over(State2) of
        {won, WinnerWall} ->
            Winner = find_node_by_wall(WinnerWall, State2#engine.players),
            logger:info("[mpong] Match won by ~s", [Winner]),
            dispatch_end_game(State2, Winner),
            {stop, normal, State2};
        playing ->
            Timer = erlang:send_after(?TICK_MS, self(), tick),
            {noreply, State2#engine{tick = Tick + 1, timer = Timer}}
    end;

handle_info(_, State) -> {noreply, State}.

terminate(_Reason, #engine{game_id = GameId}) ->
    pg:leave(pg, {mpong_engine, GameId}, self()),
    pg:leave(pg, mpong_games_available, self()),
    pg:leave(pg, {mpong_game, GameId}, self()),
    logger:info("[mpong] Engine stopped for game ~s", [GameId]),
    ok.

ensure_pg() ->
    case pg:start(pg) of
        {ok, _} -> ok;
        {error, {already_started, _}} -> ok
    end.

%%====================================================================
%% AI
%%====================================================================

run_ai(#engine{ball = Ball, paddles = Paddles, alive = Alive, player_modes = Modes} = State) ->
    BallMap = mpong_ball:to_map(Ball),
    NewPaddles = maps:map(fun(WI, CurrentY) ->
        case {maps:get(WI, Alive, false), maps:get(WI, Modes, {bot, #{}})} of
            {true, {bot, Personality}} ->
                mpong_ai:compute_paddle_position(BallMap, CurrentY, WI, Personality);
            _ ->
                CurrentY  %% dead or remote — don't touch
        end
    end, Paddles),
    State#engine{paddles = NewPaddles}.

%%====================================================================
%% Physics + scoring
%%====================================================================

step(#engine{ball = Ball0, paddles = Paddles, alive = Alive,
             obstacles = Obs0, tick = Tick} = State) ->
    Ball1 = mpong_ball:tick(Ball0),

    %% Tick obstacles (spawn/expire)
    Obs1 = mpong_obstacles:tick(Obs0, Tick),

    %% Check obstacle bounce first
    {ObsBounce, Ball2} = mpong_obstacles:check_bounce(Ball1, Obs1),
    Ball3 = case ObsBounce of bounced -> Ball2; no_bounce -> Ball1 end,

    case mpong_collision:check_paddle(Ball3, Paddles, Alive) of
        {bounced, B} ->
            State#engine{ball = B, obstacles = Obs1};
        no_bounce ->
            case mpong_collision:check_miss(Ball3, Alive) of
                {missed, WallIndex} ->
                    Scorer = 1 - WallIndex,
                    score_point(State#engine{ball = Ball3, obstacles = Obs1}, Scorer, Tick);
                none ->
                    State#engine{ball = Ball3, obstacles = Obs1}
            end
    end.

score_point(State, Scorer, Tick) ->
    OldPts = maps:get(Scorer, State#engine.points),
    NewPts = OldPts + 1,
    Points = (State#engine.points)#{Scorer => NewPts},
    TotalPts = State#engine.total_pts + 1,

    %% Serve rotation: every 2 points, or every point at deuce
    OtherPts = maps:get(1 - Scorer, Points),
    NewServing = case OtherPts >= (?GAME_POINT - 1) andalso NewPts >= (?GAME_POINT - 1) of
        true -> 1 - State#engine.serving;               %% deuce: alternate every point
        false ->
            case TotalPts rem 2 of
                0 -> 1 - State#engine.serving;           %% normal: every 2 points
                _ -> State#engine.serving
            end
    end,

    State1 = State#engine{
        points = Points,
        total_pts = TotalPts,
        serving = NewServing
    },

    %% Check if game won
    case game_won(NewPts, OtherPts) of
        true ->
            GamesWon = (State1#engine.games_won)#{Scorer => maps:get(Scorer, State1#engine.games_won) + 1},
            logger:info("[mpong] Game won by wall ~b (~b-~b), games: ~b-~b",
                        [Scorer, NewPts, OtherPts,
                         maps:get(0, GamesWon), maps:get(1, GamesWon)]),
            %% Reset for next game
            State1#engine{
                games_won = GamesWon,
                points = #{0 => 0, 1 => 0},
                total_pts = 0,
                serving = Scorer,  %% winner serves next game
                ball = mpong_ball:serve(NewServing),
                paused_until = Tick + ?COUNTDOWN_TICKS * 2  %% longer pause between games
            };
        false ->
            %% Reset ball, short pause
            State1#engine{
                ball = mpong_ball:serve(NewServing),
                paused_until = Tick + ?COUNTDOWN_TICKS
            }
    end.

game_won(Pts, OtherPts) ->
    Pts >= ?GAME_POINT andalso Pts - OtherPts >= 2.

%%====================================================================
%% Match over
%%====================================================================

check_match_over(#engine{games_won = GW}) ->
    Needed = (?BEST_OF + 1) div 2,
    case {maps:get(0, GW), maps:get(1, GW)} of
        {W, _} when W >= Needed -> {won, 0};
        {_, W} when W >= Needed -> {won, 1};
        _ -> playing
    end.

%%====================================================================
%% Broadcast
%%====================================================================

broadcast(#engine{game_id = GameId, ball = Ball, paddles = Paddles,
                  alive = Alive, points = Points, games_won = GW,
                  serving = Serving, obstacles = Obs,
                  tick = Tick, paused_until = PausedUntil}) ->
    StateMsg = #{
        game_id => GameId,
        ball => mpong_ball:to_map(Ball),
        paddles => Paddles,
        alive => Alive,
        points => Points,
        games_won => GW,
        serving => Serving,
        obstacles => mpong_obstacles:to_list(Obs),
        paused => Tick < PausedUntil,
        tick => Tick,
        arena => #{w => 1000, h => 1000}
    },
    %% Local SSE (web UI on this node)
    hecate_web_events:broadcast(mpong_state, StateMsg),
    %% Cross-node pg group (remote viewers on other cluster nodes)
    GameMembers = try pg:get_members(pg, {mpong_game, GameId}) catch _:_ -> [] end,
    [Pid ! {mpong_state, GameId, StateMsg} || Pid <- GameMembers, Pid =/= self()],
    case Tick rem 100 of
        0 ->
            logger:info("[mpong] tick=~b score=~b-~b games=~b-~b",
                        [Tick, maps:get(0, Points), maps:get(1, Points),
                         maps:get(0, GW), maps:get(1, GW)]);
        _ -> ok
    end.

%%====================================================================
%% Command dispatch
%%====================================================================

dispatch_end_game(#engine{game_id = GameId}, Winner) ->
    spawn(fun() ->
        Cmd = end_game_v1:new(GameId, Winner, <<"match_won">>),
        maybe_end_game:dispatch(GameId, Cmd)
    end).

%%====================================================================
%% Helpers
%%====================================================================

find_node_by_wall(WallIndex, Players) ->
    maps:fold(fun(NodeId, WI, Acc) ->
        case WI =:= WallIndex of true -> NodeId; false -> Acc end
    end, undefined, Players).
