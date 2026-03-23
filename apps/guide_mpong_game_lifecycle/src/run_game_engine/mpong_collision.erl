%%%-------------------------------------------------------------------
%%% @doc Collision detection for MPong (integer grid).
%%%
%%% Arena: 1000x1000. Left wall x=0, right wall x=1000.
%%% Paddles: position is 0-1000 along Y axis, height ~200.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_collision).

-export([check_paddle/3, check_miss/2]).

-define(ARENA_W, 1000).
-define(PADDLE_HALF_H, 55).  %% paddle covers 110 units (11% of arena)

%%--------------------------------------------------------------------
%% @doc Check if ball hit a paddle. Returns {bounce, Ball} or miss.
%%
%% Wall 0 = left (x=0), wall 1 = right (x=1000).
%% @end
%%--------------------------------------------------------------------
-spec check_paddle(mpong_ball:ball(), map(), map()) ->
    {bounced, mpong_ball:ball()} | no_bounce.
check_paddle(Ball, Paddles, Alive) ->
    #{x := Bx, y := By, vx := Vx, vy := Vy, r := R} = mpong_ball:to_map(Ball),

    %% Check left wall (only if ball moving left)
    case Vx < 0 andalso Bx - R =< 0 andalso maps:get(0, Alive, false) of
        true ->
            PaddleY = paddle_center(maps:get(0, Paddles, 500)),
            case abs(By - PaddleY) =< ?PADDLE_HALF_H of
                true ->
                    %% Bounce: reverse X, spin from hit offset + randomness
                    Offset = By - PaddleY,
                    Spin = Offset div 4,
                    Jitter = rand:uniform(5) - 3,  %% -2 to +2
                    NewVy = Vy + Spin + Jitter,
                    %% Speed up slightly each bounce
                    NewVx = min(14, abs(Vx) + 1),
                    NewBall = set_ball(R + 1, By, NewVx, NewVy, R, Offset),
                    {bounced, NewBall};
                false ->
                    no_bounce
            end;
        _ ->
            %% Check right wall (only if ball moving right)
            case Vx > 0 andalso Bx + R >= ?ARENA_W andalso maps:get(1, Alive, false) of
                true ->
                    PaddleY1 = paddle_center(maps:get(1, Paddles, 500)),
                    case abs(By - PaddleY1) =< ?PADDLE_HALF_H of
                        true ->
                            Offset1 = By - PaddleY1,
                            Spin1 = Offset1 div 4,
                            Jitter1 = rand:uniform(5) - 3,
                            NewVy1 = Vy + Spin1 + Jitter1,
                            NewVx1 = min(14, abs(Vx) + 1),
                            NewBall1 = set_ball(?ARENA_W - R - 1, By, -NewVx1, NewVy1, R, Offset1),
                            {bounced, NewBall1};
                        false ->
                            no_bounce
                    end;
                _ ->
                    no_bounce
            end
    end.

%%--------------------------------------------------------------------
%% @doc Check if ball passed a wall (miss → elimination).
%% @end
%%--------------------------------------------------------------------
-spec check_miss(mpong_ball:ball(), map()) -> {missed, non_neg_integer()} | none.
check_miss(Ball, Alive) ->
    #{x := Bx, r := R} = mpong_ball:to_map(Ball),
    case {Bx - R =< -20, Bx + R >= ?ARENA_W + 20} of
        {true, _} ->
            case maps:get(0, Alive, false) of
                true -> {missed, 0};
                false -> none
            end;
        {_, true} ->
            case maps:get(1, Alive, false) of
                true -> {missed, 1};
                false -> none
            end;
        _ ->
            none
    end.

%%====================================================================
%% Internal
%%====================================================================

%% Paddle position (0-1000) is the center Y coordinate
paddle_center(Pos) -> Pos.

%% Construct a new ball state with spin and random power/dampen
set_ball(X, Y, Vx, Vy, R, Offset) ->
    %% Random power mechanic: 1-in-5 chance of power shot or soft touch
    {VxMod, VyMod} = case rand:uniform(10) of
        1 -> {3, 2};      %% SMASH — big speed boost
        2 -> {2, 1};      %% power shot
        9 -> {-3, -1};    %% soft touch — slow it down
        10 -> {-4, -2};   %% drop shot — very slow
        _ -> {0, 0}       %% normal
    end,
    Vx2 = Vx + sign(Vx) * VxMod,
    Vy2 = Vy + sign(Vy) * VyMod,
    %% Clamp speeds
    Vx3 = case abs(Vx2) < 5 of true -> sign(Vx2) * 5; false -> Vx2 end,
    Vx4 = case abs(Vx3) > 18 of true -> sign(Vx3) * 18; false -> Vx3 end,
    Vy3 = max(-14, min(14, Vy2)),
    %% Spin from paddle hit offset
    Spin = max(-3, min(3, Offset div 30)),
    mpong_ball:from_map(#{x => X, y => Y, vx => Vx4, vy => Vy3, r => R, spin => Spin}).

sign(X) when X >= 0 -> 1;
sign(_) -> -1.
