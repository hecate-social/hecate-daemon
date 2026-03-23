%%%-------------------------------------------------------------------
%%% @doc Octagonal (N-gonal) arena geometry for MPong.
%%%
%%% Computes wall segments for 2-8 players.
%%% - 2 players: classic pong with two parallel vertical walls
%%% - 3+ players: regular polygon with one wall per player
%%% Center at {0, 0}, radius 1.0 (normalized coordinates).
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_arena).

-export([new/1, wall_segment/2, wall_count/1, walls/1, radius/1]).
-export_type([arena/0]).

-record(arena, {
    player_count :: pos_integer(),
    radius       :: float(),
    walls        :: [wall()]
}).

-type arena() :: #arena{}.
-type point() :: {float(), float()}.
-type wall() :: {point(), point()}.

%%--------------------------------------------------------------------
%% @doc Create a new arena for N players.
%% @end
%%--------------------------------------------------------------------
-spec new(pos_integer()) -> arena().
new(PlayerCount) when PlayerCount >= 2, PlayerCount =< 8 ->
    R = 1.0,
    Walls = compute_walls(PlayerCount, R),
    #arena{player_count = PlayerCount, radius = R, walls = Walls}.

%%--------------------------------------------------------------------
%% @doc Get the wall segment for a given wall index.
%% @end
%%--------------------------------------------------------------------
-spec wall_segment(arena(), non_neg_integer()) -> wall().
wall_segment(#arena{walls = Walls}, Index) ->
    lists:nth(Index + 1, Walls).

%%--------------------------------------------------------------------
%% @doc Get all walls.
%% @end
%%--------------------------------------------------------------------
-spec walls(arena()) -> [wall()].
walls(#arena{walls = Walls}) -> Walls.

%%--------------------------------------------------------------------
%% @doc Get number of walls.
%% @end
%%--------------------------------------------------------------------
-spec wall_count(arena()) -> pos_integer().
wall_count(#arena{player_count = N}) -> N.

%%--------------------------------------------------------------------
%% @doc Get arena radius.
%% @end
%%--------------------------------------------------------------------
-spec radius(arena()) -> float().
radius(#arena{radius = R}) -> R.

%%====================================================================
%% Internal
%%====================================================================

%% 2 players: classic pong — two parallel vertical walls
compute_walls(2, R) ->
    [{{-R, -R}, {-R, R}},     %% Left wall (player 0)
     {{R, R}, {R, -R}}];      %% Right wall (player 1)

%% 3+ players: regular polygon
compute_walls(N, R) ->
    Vertices = [vertex(I, N, R) || I <- lists:seq(0, N - 1)],
    pairs(Vertices).

pairs(Vertices) ->
    pairs(Vertices, Vertices, []).

pairs([A], [H | _], Acc) ->
    lists:reverse([{A, H} | Acc]);
pairs([A, B | Rest], All, Acc) ->
    pairs([B | Rest], All, [{A, B} | Acc]).

vertex(I, N, R) ->
    Angle = (2.0 * math:pi() * I / N) - (math:pi() / 2.0),
    {R * math:cos(Angle), R * math:sin(Angle)}.
