%%% @doc Actuator for snake gladiator — converts 4 network outputs to direction.
%%%
%%% Takes argmax of [up, down, left, right] output values.
%%% Filters reverse direction to prevent 180-degree turns.
%%% @end
-module(gladiator_actuator).
-behaviour(agent_actuator).

-include_lib("run_snake_duel/include/snake_duel.hrl").
-include("gladiator.hrl").

-export([name/0, output_count/0, act/3]).

-spec name() -> binary().
name() -> <<"gladiator_motor">>.

-spec output_count() -> pos_integer().
output_count() -> ?GLADIATOR_OUTPUTS.

-spec act([float()], map(), map()) -> {ok, term()} | {error, term()}.
act(Outputs, _AgentState, #{game := Game}) ->
    CurrentDir = (Game#game_state.snake1)#snake.direction,
    Reverse = reverse_dir(CurrentDir),
    Dir = pick_direction(Outputs, Reverse),
    {ok, Dir}.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

pick_direction([Up, Down, Left, Right], Reverse) ->
    Candidates = [
        {Up, up},
        {Down, down},
        {Left, left},
        {Right, right}
    ],
    %% Filter out the reverse direction, then take argmax
    Filtered = [{Val, Dir} || {Val, Dir} <- Candidates, Dir =/= Reverse],
    {_, BestDir} = lists:max(Filtered),
    BestDir.

reverse_dir(up)    -> down;
reverse_dir(down)  -> up;
reverse_dir(left)  -> right;
reverse_dir(right) -> left.
