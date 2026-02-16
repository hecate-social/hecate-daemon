%%% @doc Shared venture_state record definition.
%%%
%%% Include this from venture_aggregate.erl and test files to prevent
%%% record drift between production code and tests.
-ifndef(VENTURE_STATE_HRL).
-define(VENTURE_STATE_HRL, true).

-record(venture_state, {
    venture_id          :: binary() | undefined,
    name                :: binary() | undefined,
    brief               :: binary() | undefined,
    status = 0          :: non_neg_integer(),
    repo_path           :: binary() | undefined,
    repos = []          :: [binary()],
    skills = []         :: [binary()],
    context_map = #{}   :: map(),
    discovered_divisions = #{} :: #{binary() => binary()},
    initiated_at        :: non_neg_integer() | undefined,
    initiated_by        :: binary() | undefined,
    discovery_started_at   :: non_neg_integer() | undefined,
    discovery_paused_at    :: non_neg_integer() | undefined,
    discovery_completed_at :: non_neg_integer() | undefined,
    discovery_pause_reason :: binary() | undefined,
    %% Big Picture Event Storming
    storm_number = 0           :: non_neg_integer(),
    storm_phase = undefined    :: atom(),
    storm_started_at           :: non_neg_integer() | undefined,
    storm_shelved_at           :: non_neg_integer() | undefined,
    event_stickies = #{}       :: #{binary() => map()},
    event_stacks = #{}         :: #{binary() => map()},
    event_clusters = #{}       :: #{binary() => map()},
    fact_arrows = #{}          :: #{binary() => map()}
}).

-endif.
