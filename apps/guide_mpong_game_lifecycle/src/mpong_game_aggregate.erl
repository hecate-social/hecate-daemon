%%%-------------------------------------------------------------------
%%% @doc MPong game aggregate.
%%%
%%% Routes commands to desk handlers with state-based guards.
%%% Business rules:
%%% - Only host can start/end game
%%% - Players can only join hosted (not started) games
%%% - Game needs at least 2 players to start
%%% - Elimination only during active game
%%% - Game ends when one player remains or host forces end
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_game_aggregate).
-behaviour(evoq_aggregate).

-include("mpong_game_state.hrl").
-include("mpong_game_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/1]).

%%--------------------------------------------------------------------
%% @doc State module for this aggregate.
%% @end
%%--------------------------------------------------------------------
state_module() -> mpong_game_state.

%%--------------------------------------------------------------------
%% @doc Initialize a new aggregate.
%% @end
%%--------------------------------------------------------------------
init(AggregateId) ->
    {ok, mpong_game_state:new(AggregateId)}.

%%--------------------------------------------------------------------
%% @doc Compute stream ID from game ID.
%% @end
%%--------------------------------------------------------------------
-spec stream_id(binary()) -> binary().
stream_id(GameId) ->
    <<"mpong_game-", GameId/binary>>.

%%--------------------------------------------------------------------
%% @doc Execute a command against current state.
%% @end
%%--------------------------------------------------------------------
execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

%%--------------------------------------------------------------------
%% @doc Apply an event to update state.
%% @end
%%--------------------------------------------------------------------
apply(State, Event) ->
    mpong_game_state:apply_event(State, Event).

%%====================================================================
%% Internal: Command routing with state guards
%%====================================================================

%% Host a new game — must not already be hosted
do_execute(host_game, State, Payload) ->
    case State#mpong_game_state.status band ?MPONG_HOSTED of
        0 -> maybe_host_game:handle_from_map(Payload);
        _ -> {error, already_hosted}
    end;

%% Join a game — must be hosted, not started, not full
do_execute(join_game, State, Payload) ->
    case State#mpong_game_state.status band ?MPONG_HOSTED of
        0 -> {error, not_hosted};
        _ ->
            case State#mpong_game_state.status band ?MPONG_STARTED of
                0 ->
                    PlayerCount = maps:size(State#mpong_game_state.players),
                    MaxPlayers = State#mpong_game_state.max_players,
                    NodeId = maps:get(player_node_id, Payload, maps:get(<<"player_node_id">>, Payload, <<>>)),
                    case {PlayerCount >= MaxPlayers, maps:is_key(NodeId, State#mpong_game_state.players)} of
                        {true, _} -> {error, game_full};
                        {_, true} -> {error, already_joined};
                        _ ->
                            NextWall = PlayerCount,
                            maybe_join_game:handle_from_map(Payload#{wall_index => NextWall})
                    end;
                _ -> {error, game_already_started}
            end
    end;

%% Leave a game — must be joined, game not started
do_execute(leave_game, State, Payload) ->
    case State#mpong_game_state.status band ?MPONG_STARTED of
        0 ->
            NodeId = maps:get(player_node_id, Payload, maps:get(<<"player_node_id">>, Payload, <<>>)),
            case maps:is_key(NodeId, State#mpong_game_state.players) of
                true -> maybe_leave_game:handle_from_map(Payload);
                false -> {error, not_in_game}
            end;
        _ -> {error, game_already_started}
    end;

%% Start a game — must be hosted, not started, at least 2 players, only host
do_execute(start_game, State, Payload) ->
    case State#mpong_game_state.status band ?MPONG_HOSTED of
        0 -> {error, not_hosted};
        _ ->
            case State#mpong_game_state.status band ?MPONG_STARTED of
                0 ->
                    HostId = State#mpong_game_state.host_node_id,
                    RequesterId = maps:get(host_node_id, Payload, maps:get(<<"host_node_id">>, Payload, <<>>)),
                    PlayerCount = maps:size(State#mpong_game_state.players),
                    case {RequesterId =:= HostId, PlayerCount >= 2} of
                        {false, _} -> {error, only_host_can_start};
                        {_, false} -> {error, need_at_least_2_players};
                        _ -> maybe_start_game:handle_from_map(Payload#{player_count => PlayerCount})
                    end;
                _ -> {error, game_already_started}
            end
    end;

%% Eliminate a player — game must be started, player must be alive
do_execute(eliminate_player, State, Payload) ->
    case State#mpong_game_state.status band ?MPONG_STARTED of
        0 -> {error, game_not_started};
        _ ->
            NodeId = maps:get(player_node_id, Payload, maps:get(<<"player_node_id">>, Payload, <<>>)),
            case maps:find(NodeId, State#mpong_game_state.players) of
                {ok, #{alive := true}} ->
                    Remaining = count_alive(State#mpong_game_state.players) - 1,
                    maybe_eliminate_player:handle_from_map(Payload#{remaining_count => Remaining});
                {ok, #{alive := false}} ->
                    {error, already_eliminated};
                error ->
                    {error, player_not_found}
            end
    end;

%% End a game — game must be started
do_execute(end_game, State, Payload) ->
    case State#mpong_game_state.status band ?MPONG_STARTED of
        0 -> {error, game_not_started};
        _ ->
            case State#mpong_game_state.status band ?MPONG_ENDED of
                0 -> maybe_end_game:handle_from_map(Payload);
                _ -> {error, game_already_ended}
            end
    end;

%% Register a champion bot for this node — always allowed
do_execute(register_champion, _State, Payload) ->
    maybe_register_champion:handle_from_map(Payload);

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

%%====================================================================
%% Internal helpers
%%====================================================================

count_alive(Players) ->
    maps:fold(fun(_NodeId, #{alive := true}, Acc) -> Acc + 1;
                 (_NodeId, _, Acc) -> Acc
              end, 0, Players).
