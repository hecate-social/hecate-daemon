%%%-------------------------------------------------------------------
%%% @doc Random temporary obstacles for MPong.
%%%
%%% Obstacles are rectangles that appear/disappear on a timer.
%%% Ball bounces off them. Creates unpredictable gameplay.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_obstacles).

-export([new/0, tick/2, check_bounce/2, to_list/1]).

-record(obstacle, {
    x      :: integer(),   %% center x
    y      :: integer(),   %% center y
    hw     :: integer(),   %% half-width
    hh     :: integer(),   %% half-height
    ttl    :: integer()    %% ticks remaining
}).

-record(obstacles, {
    items     :: [#obstacle{}],
    next_spawn :: integer()    %% tick when next obstacle spawns
}).

-define(MAX_OBSTACLES, 3).
-define(MIN_TTL, 100).    %% 4 seconds
-define(MAX_TTL, 250).    %% 10 seconds
-define(SPAWN_MIN, 75).   %% 3 seconds between spawns
-define(SPAWN_MAX, 200).  %% 8 seconds between spawns
-define(OBS_HW, 30).      %% half-width
-define(OBS_HH, 30).      %% half-height

new() ->
    #obstacles{items = [], next_spawn = 50 + rand:uniform(100)}.

%% @doc Tick: decrement TTLs, remove expired, maybe spawn new.
tick(#obstacles{items = Items, next_spawn = NextSpawn} = Obs, Tick) ->
    %% Decrement TTLs, remove dead
    Alive = [O#obstacle{ttl = O#obstacle.ttl - 1} || O <- Items, O#obstacle.ttl > 1],

    %% Maybe spawn new
    case Tick >= NextSpawn andalso length(Alive) < ?MAX_OBSTACLES of
        true ->
            New = spawn_obstacle(),
            Next = Tick + ?SPAWN_MIN + rand:uniform(?SPAWN_MAX - ?SPAWN_MIN),
            Obs#obstacles{items = [New | Alive], next_spawn = Next};
        false ->
            Obs#obstacles{items = Alive}
    end.

%% @doc Check if ball hits any obstacle. Returns {bounced, NewBall} or no_bounce.
check_bounce(Ball, #obstacles{items = Items}) ->
    #{x := Bx, y := By, vx := Vx, vy := Vy, r := Br} = mpong_ball:to_map(Ball),
    check_items(Bx, By, Vx, Vy, Br, Items, Ball).

%% @doc Serialize for frontend rendering.
to_list(#obstacles{items = Items}) ->
    [#{x => O#obstacle.x, y => O#obstacle.y,
       hw => O#obstacle.hw, hh => O#obstacle.hh,
       ttl => O#obstacle.ttl} || O <- Items].

%%====================================================================
%% Internal
%%====================================================================

spawn_obstacle() ->
    %% Place in the middle zone (away from paddles)
    X = 250 + rand:uniform(500),   %% 250-750 (center area)
    Y = 100 + rand:uniform(800),   %% 100-900
    HW = 20 + rand:uniform(25),    %% 20-45
    HH = 20 + rand:uniform(25),
    TTL = ?MIN_TTL + rand:uniform(?MAX_TTL - ?MIN_TTL),
    #obstacle{x = X, y = Y, hw = HW, hh = HH, ttl = TTL}.

check_items(_Bx, _By, _Vx, _Vy, _Br, [], Ball) ->
    {no_bounce, Ball};
check_items(Bx, By, Vx, Vy, Br, [#obstacle{x = Ox, y = Oy, hw = HW, hh = HH} | Rest], Ball) ->
    %% AABB collision: ball center within expanded obstacle rect
    case Bx + Br >= Ox - HW andalso Bx - Br =< Ox + HW andalso
         By + Br >= Oy - HH andalso By - Br =< Oy + HH of
        true ->
            %% Determine bounce direction (which face was hit)
            DxLeft = abs(Bx - (Ox - HW)),
            DxRight = abs(Bx - (Ox + HW)),
            DyTop = abs(By - (Oy - HH)),
            DyBot = abs(By - (Oy + HH)),
            MinDx = min(DxLeft, DxRight),
            MinDy = min(DyTop, DyBot),
            {NewVx, NewVy} = case MinDx =< MinDy of
                true  -> {-Vx, Vy};   %% hit side face
                false -> {Vx, -Vy}    %% hit top/bottom face
            end,
            %% Add jitter
            Jitter = rand:uniform(3) - 2,
            NewBall = mpong_ball:from_map(#{
                x => Bx + sign(NewVx) * 3,
                y => By + sign(NewVy) * 3,
                vx => NewVx + Jitter,
                vy => NewVy + Jitter,
                r => Br,
                spin => rand:uniform(5) - 3
            }),
            {bounced, NewBall};
        false ->
            check_items(Bx, By, Vx, Vy, Br, Rest, Ball)
    end.

sign(X) when X >= 0 -> 1;
sign(_) -> -1.
