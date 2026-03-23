%%%-------------------------------------------------------------------
%%% @doc Paddle state for MPong.
%%%
%%% Each paddle sits on a wall segment. Position is 0.0-1.0 along the wall.
%%% Width is a fraction of wall length (default 0.2 = 20% of wall).
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_paddle).

-export([paddle_segment/3]).

-define(PADDLE_WIDTH, 0.2).

%%--------------------------------------------------------------------
%% @doc Compute paddle line segment on a wall.
%%
%% Given wall endpoints {P1, P2}, paddle position (0.0-1.0),
%% returns {PaddleStart, PaddleEnd} as points on the wall.
%% @end
%%--------------------------------------------------------------------
-spec paddle_segment({point(), point()}, float(), float()) -> {point(), point()}.
paddle_segment({{X1, Y1}, {X2, Y2}}, Position, Width) ->
    HalfW = Width / 2.0,
    Start = max(0.0, Position - HalfW),
    End = min(1.0, Position + HalfW),
    PaddleStart = {X1 + (X2 - X1) * Start, Y1 + (Y2 - Y1) * Start},
    PaddleEnd = {X1 + (X2 - X1) * End, Y1 + (Y2 - Y1) * End},
    {PaddleStart, PaddleEnd}.

-type point() :: {float(), float()}.
