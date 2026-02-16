%%% @doc Actuator for snake gladiator — converts 5 network outputs to action.
%%%
%%% Takes argmax of first 4 outputs [up, down, left, right] for direction.
%%% 5th output is drop-tail signal (> 0.5 = drop wall).
%%% Filters reverse direction to prevent 180-degree turns.
%%% Returns {Dir, DropTail} tuple.
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
    {Dir, DropTail} = pick_action(Outputs, Reverse),
    {ok, {Dir, DropTail}}.

%%--------------------------------------------------------------------
%% Internal
%%--------------------------------------------------------------------

pick_action([Up, Down, Left, Right | DropRest], Reverse) ->
    Candidates = [
        {Up, up},
        {Down, down},
        {Left, left},
        {Right, right}
    ],
    %% Filter out the reverse direction, then take argmax
    Filtered = [{Val, Dir} || {Val, Dir} <- Candidates, Dir =/= Reverse],
    {_, BestDir} = lists:max(Filtered),
    %% 5th output is drop-tail signal (> 0.5 = drop)
    DropSignal = case DropRest of
        [D | _] -> D > 0.5;
        [] -> false
    end,
    {BestDir, DropSignal}.

reverse_dir(up)    -> down;
reverse_dir(down)  -> up;
reverse_dir(left)  -> right;
reverse_dir(right) -> left.
