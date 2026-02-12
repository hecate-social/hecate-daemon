%%% @doc Status bit flags for the division ALC aggregate.
%%%
%%% Overall status: initiated, archived
%%% Per-phase status (reused for dna, anp, tni, dno fields):
%%%   active -> paused -> completed
%%% @end

-ifndef(DIVISION_ALC_STATUS_HRL).
-define(DIVISION_ALC_STATUS_HRL, true).

%% Overall division status
-define(DA_INITIATED,  1).   %% 2^0
-define(DA_ARCHIVED,   2).   %% 2^1

%% Per-phase status (reused for each phase field)
-define(PHASE_ACTIVE,    1).   %% 2^0
-define(PHASE_PAUSED,    2).   %% 2^1
-define(PHASE_COMPLETED, 4).   %% 2^2

-define(DA_FLAG_MAP, #{
    ?DA_INITIATED => <<"Initiated">>,
    ?DA_ARCHIVED  => <<"Archived">>
}).

-define(PHASE_FLAG_MAP, #{
    0                => <<"Pending">>,
    ?PHASE_ACTIVE    => <<"Active">>,
    ?PHASE_PAUSED    => <<"Paused">>,
    ?PHASE_COMPLETED => <<"Completed">>
}).

%% Valid phase atoms
-define(VALID_PHASES, [dna, anp, tni, dno]).

-endif.
