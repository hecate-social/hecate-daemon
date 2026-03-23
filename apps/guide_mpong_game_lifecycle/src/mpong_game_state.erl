%%%-------------------------------------------------------------------
%%% @doc MPong game aggregate state.
%%%
%%% Tracks game lifecycle from hosting through player join/leave,
%%% game start, player elimination, to game end.
%%% @end
%%%-------------------------------------------------------------------
-module(mpong_game_state).
-behaviour(evoq_state).

-include("mpong_game_state.hrl").
-include("mpong_game_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

%%--------------------------------------------------------------------
%% @doc Create a new empty state for the given aggregate ID.
%% @end
%%--------------------------------------------------------------------
-spec new(binary()) -> #mpong_game_state{}.
new(_AggregateId) ->
    #mpong_game_state{
        game_id = undefined,
        host_node_id = undefined,
        players = #{},
        max_players = 8,
        status = 0,
        hosted_at = undefined,
        started_at = undefined,
        ended_at = undefined,
        winner_node_id = undefined
    }.

%%--------------------------------------------------------------------
%% @doc Apply a domain event to update state.
%% @end
%%--------------------------------------------------------------------
-spec apply_event(#mpong_game_state{}, map()) -> #mpong_game_state{}.
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%%--------------------------------------------------------------------
%% @doc Serialize state to map.
%% @end
%%--------------------------------------------------------------------
-spec to_map(#mpong_game_state{}) -> map().
to_map(#mpong_game_state{} = S) ->
    #{
        game_id => S#mpong_game_state.game_id,
        host_node_id => S#mpong_game_state.host_node_id,
        players => S#mpong_game_state.players,
        max_players => S#mpong_game_state.max_players,
        status => S#mpong_game_state.status,
        hosted_at => S#mpong_game_state.hosted_at,
        started_at => S#mpong_game_state.started_at,
        ended_at => S#mpong_game_state.ended_at,
        winner_node_id => S#mpong_game_state.winner_node_id
    }.

%%====================================================================
%% Internal: Event application
%%====================================================================

do_apply(<<"game_hosted_v1">>, State, Event) ->
    State#mpong_game_state{
        game_id = field(<<"game_id">>, game_id, Event),
        host_node_id = field(<<"host_node_id">>, host_node_id, Event),
        max_players = field(<<"max_players">>, max_players, Event, 8),
        hosted_at = field(<<"hosted_at">>, hosted_at, Event),
        status = State#mpong_game_state.status bor ?MPONG_HOSTED
    };

do_apply(<<"player_joined_v1">>, State, Event) ->
    NodeId = field(<<"player_node_id">>, player_node_id, Event),
    WallIndex = field(<<"wall_index">>, wall_index, Event),
    JoinedAt = field(<<"joined_at">>, joined_at, Event),
    PlayerInfo = #{wall_index => WallIndex, alive => true, joined_at => JoinedAt},
    Players = maps:put(NodeId, PlayerInfo, State#mpong_game_state.players),
    State#mpong_game_state{players = Players};

do_apply(<<"player_left_v1">>, State, Event) ->
    NodeId = field(<<"player_node_id">>, player_node_id, Event),
    Players = maps:remove(NodeId, State#mpong_game_state.players),
    State#mpong_game_state{players = Players};

do_apply(<<"game_started_v1">>, State, Event) ->
    State#mpong_game_state{
        started_at = field(<<"started_at">>, started_at, Event),
        status = State#mpong_game_state.status bor ?MPONG_STARTED
    };

do_apply(<<"player_eliminated_v1">>, State, Event) ->
    NodeId = field(<<"player_node_id">>, player_node_id, Event),
    case maps:find(NodeId, State#mpong_game_state.players) of
        {ok, Info} ->
            Players = maps:put(NodeId, Info#{alive => false}, State#mpong_game_state.players),
            State#mpong_game_state{players = Players};
        error ->
            State
    end;

do_apply(<<"game_ended_v1">>, State, Event) ->
    State#mpong_game_state{
        winner_node_id = field(<<"winner_node_id">>, winner_node_id, Event),
        ended_at = field(<<"ended_at">>, ended_at, Event),
        status = State#mpong_game_state.status bor ?MPONG_ENDED
    };

do_apply(_Unknown, State, _Event) ->
    State.

%%====================================================================
%% Internal: Field extraction (handles both atom and binary keys)
%%====================================================================

field(BinKey, AtomKey, Event) ->
    field(BinKey, AtomKey, Event, undefined).

field(BinKey, AtomKey, Event, Default) ->
    case maps:find(AtomKey, Event) of
        {ok, Val} -> Val;
        error ->
            case maps:find(BinKey, Event) of
                {ok, Val} -> Val;
                error -> Default
            end
    end.
