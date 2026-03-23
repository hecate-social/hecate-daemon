%%% @doc MPong game aggregate state record.
%%% Tracks game lifecycle: hosting, players joining, game play, elimination, end.

-record(mpong_game_state, {
    game_id        :: binary() | undefined,
    host_node_id   :: binary() | undefined,
    %% #{NodeId => #{wall_index => integer(), alive => boolean(), joined_at => integer()}}
    players        :: map(),
    max_players    :: pos_integer(),
    status         :: non_neg_integer(),
    hosted_at      :: integer() | undefined,
    started_at     :: integer() | undefined,
    ended_at       :: integer() | undefined,
    winner_node_id :: binary() | undefined
}).
