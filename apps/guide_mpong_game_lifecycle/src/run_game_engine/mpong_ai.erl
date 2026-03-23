%%%-------------------------------------------------------------------
%%% @doc AI for MPong paddle control (integer grid).
%%%
%%% Accepts a personality map from champion registration.
%%% Falls back to random personality if map is empty.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_ai).

-export([compute_paddle_position/3, compute_paddle_position/4]).

%% @doc Legacy 3-arity (uses persistent_term personalities).
-spec compute_paddle_position(map(), integer(), integer()) -> integer().
compute_paddle_position(BallMap, CurrentY, WallIndex) ->
    compute_paddle_position(BallMap, CurrentY, WallIndex, #{}).

%% @doc With explicit personality map from champion.
-spec compute_paddle_position(map(), integer(), integer(), map()) -> integer().
compute_paddle_position(#{y := BallY, vx := BallVx}, CurrentY, WallIndex, Personality) ->
    P = resolve_personality(WallIndex, Personality),
    #{speed := Speed, bias_range := BiasRange, err_rate := ErrRate,
      err_mag := ErrMag, aggression := Aggression} = P,

    %% Bias: aim off-center for spin (within bias_range)
    Bias = case BiasRange > 0 of
        true -> (rand:uniform(3) - 2) * BiasRange;
        false -> 0
    end,

    %% Track ball when coming toward us, drift to center otherwise
    Target = case {WallIndex, BallVx} of
        {0, Vx} when Vx < 0 -> BallY + Bias;
        {1, Vx} when Vx > 0 -> BallY + Bias;
        _ ->
            CenterBias = 500 + (Bias div 2),
            CurrentY + (CenterBias - CurrentY) div Aggression
    end,

    %% Occasional mistakes
    Target2 = case rand:uniform(ErrRate) of
        1 -> Target + (rand:uniform(ErrMag * 2 + 1) - ErrMag - 1);
        _ -> Target
    end,

    Diff = Target2 - CurrentY,
    Move = max(-Speed, min(Speed, Diff)),
    NewY = CurrentY + Move,
    max(70, min(930, NewY)).

%%====================================================================
%% Internal
%%====================================================================

%% Use champion personality if provided, else persistent_term, else random
resolve_personality(_WallIndex, Personality) when map_size(Personality) > 0 ->
    #{speed => maps:get(speed, Personality, 10),
      bias_range => maps:get(bias_range, Personality, 0),
      err_rate => maps:get(err_rate, Personality, 10),
      err_mag => maps:get(err_mag, Personality, 30),
      aggression => maps:get(aggression, Personality, 3)};
resolve_personality(WallIndex, _Empty) ->
    %% Fallback to persistent_term (legacy quick_start mode)
    case persistent_term:get({mpong_personality, WallIndex}, undefined) of
        undefined ->
            P = random_personality(),
            persistent_term:put({mpong_personality, WallIndex}, P),
            P;
        P -> P
    end.

random_personality() ->
    BaseSpeed = 9 + rand:uniform(3),
    BaseErr = 8 + rand:uniform(8),
    #{speed => BaseSpeed,
      bias_range => rand:uniform(40),
      err_rate => BaseErr,
      err_mag => 25 + rand:uniform(25),
      aggression => 2 + rand:uniform(3)}.
