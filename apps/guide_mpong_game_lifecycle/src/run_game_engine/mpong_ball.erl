%%%-------------------------------------------------------------------
%%% @doc Ball physics for MPong.
%%%
%%% Integer grid: arena is 1000x1000, center at {500, 500}.
%%% Walls at x=0 (left) and x=1000 (right).
%%% Top/bottom at y=0 and y=1000.
%%% Ball radius is ~15 units.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_ball).

-export([new/0, tick/1, reset/0, serve/1, to_map/1, from_map/1]).
-export_type([ball/0]).

-record(ball, {
    x     :: integer(),
    y     :: integer(),
    vx    :: integer(),
    vy    :: integer(),
    r     :: integer(),
    spin  :: integer()   %% applied to vy on wall bounce (-3 to +3)
}).

-type ball() :: #ball{}.

-define(ARENA_W, 1000).
-define(ARENA_H, 1000).
-define(RADIUS, 15).
-define(INITIAL_SPEED, 11).  %% pixels per tick

new() -> serve(rand:uniform(2) - 1).

reset() ->
    %% Random angle biased toward horizontal
    Angle = case rand:uniform(4) of
        1 -> 30 + rand:uniform(30);    %% 30-60 degrees
        2 -> 120 + rand:uniform(30);   %% 120-150
        3 -> 210 + rand:uniform(30);   %% 210-240
        4 -> 300 + rand:uniform(30)    %% 300-330
    end,
    Rad = Angle * math:pi() / 180.0,
    Vx = round(?INITIAL_SPEED * math:cos(Rad)),
    Vy = round(?INITIAL_SPEED * math:sin(Rad)),
    %% Ensure non-zero horizontal velocity
    Vx2 = case Vx of 0 -> ?INITIAL_SPEED; _ -> Vx end,
    #ball{x = ?ARENA_W div 2, y = ?ARENA_H div 2, vx = Vx2, vy = Vy, r = ?RADIUS, spin = 0}.

%% Serve toward a specific wall (0=left, 1=right).
serve(WallIndex) ->
    Vy = (rand:uniform(9) - 5),  %% -4 to +4
    Vx = ?INITIAL_SPEED,
    Dir = case WallIndex of 0 -> -1; _ -> 1 end,
    #ball{x = ?ARENA_W div 2, y = ?ARENA_H div 2,
          vx = Vx * Dir, vy = Vy, r = ?RADIUS, spin = 0}.

%% Move ball one tick. Bounce off top/bottom.
tick(#ball{x = X, y = Y, vx = Vx, vy = Vy, r = R} = Ball) ->
    X2 = X + Vx,
    Y2 = Y + Vy,
    %% Bounce off top (y=0) and bottom (y=ARENA_H)
    {Y3, Vy2} = bounce_y(Y2, Vy, R),
    %% Apply spin on wall bounce (shifts horizontal velocity slightly)
    Vx2 = case Y3 =/= Y2 of
        true -> Vx + Ball#ball.spin;
        false -> Vx
    end,
    Ball#ball{x = X2, y = Y3, vx = Vx2, vy = Vy2}.

to_map(#ball{x = X, y = Y, vx = Vx, vy = Vy, r = R, spin = Spin}) ->
    #{x => X, y => Y, vx => Vx, vy => Vy, r => R, spin => Spin}.

from_map(#{x := X, y := Y, vx := Vx, vy := Vy, r := R} = M) ->
    Spin = maps:get(spin, M, 0),
    #ball{x = X, y = Y, vx = Vx, vy = Vy, r = R, spin = Spin}.

%%====================================================================
%% Internal
%%====================================================================

bounce_y(Y, Vy, R) ->
    if
        Y - R =< 0 ->
            {R, abs(Vy)};
        Y + R >= ?ARENA_H ->
            {?ARENA_H - R, -abs(Vy)};
        true ->
            {Y, Vy}
    end.
