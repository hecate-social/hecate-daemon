%%% @doc Venture aggregate — unified lifecycle for inception + discovery.
%%%
%%% Absorbs: setup_aggregate (setup_venture) + discovery_aggregate (discover_divisions)
%%% Stream: venture-{venture_id}
%%% Store: dev_studio_store
%%%
%%% Lifecycle:
%%%   1. initiate_venture (birth event)
%%%   2. refine_vision / submit_vision (inception phase)
%%%   3. start_discovery / identify_division / pause/resume/complete_discovery
%%%   4. archive_venture (walking skeleton)
%%% @end
-module(venture_aggregate).

-behaviour(evoq_aggregate).

-include("venture_lifecycle_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([initial_state/0, apply_event/2]).
-export([flag_map/0]).

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

-type state() :: #venture_state{}.
-export_type([state/0]).

-spec flag_map() -> evoq_bit_flags:flag_map().
flag_map() -> ?VL_FLAG_MAP.

%% --- Callbacks ---

-spec init(binary()) -> {ok, state()}.
init(_AggregateId) ->
    {ok, initial_state()}.

-spec initial_state() -> state().
initial_state() ->
    #venture_state{}.

%% --- Execute ---
%% NOTE: evoq calls execute(State, Payload) - State FIRST!

-spec execute(state(), map()) -> {ok, [map()]} | {error, term()}.

%% Fresh aggregate — only initiate allowed
execute(#venture_state{status = 0}, Payload) ->
    case get_command_type(Payload) of
        <<"initiate_venture">> -> execute_initiate_venture(Payload);
        _ -> {error, venture_not_initiated}
    end;

%% Archived — nothing allowed
execute(#venture_state{status = S}, _Payload) when S band ?VL_ARCHIVED =/= 0 ->
    {error, venture_archived};

%% Initiated and not archived — route by command type
execute(#venture_state{status = S} = State, Payload) when S band ?VL_INITIATED =/= 0 ->
    case get_command_type(Payload) of
        <<"refine_vision">>      -> execute_refine_vision(Payload, State);
        <<"submit_vision">>      -> execute_submit_vision(Payload, State);
        <<"start_discovery">>    -> execute_start_discovery(Payload, State);
        <<"identify_division">>  -> execute_identify_division(Payload, State);
        <<"pause_discovery">>    -> execute_pause_discovery(Payload, State);
        <<"resume_discovery">>   -> execute_resume_discovery(Payload, State);
        <<"complete_discovery">> -> execute_complete_discovery(Payload, State);
        <<"archive_venture">>    -> execute_archive_venture(Payload, State);
        %% Scaffold
        <<"scaffold_venture_repo">> -> execute_scaffold_venture_repo(Payload, State);
        %% Big Picture Event Storming
        <<"start_big_picture_storm">>   -> execute_start_storm(Payload, State);
        <<"post_event_sticky">>         -> execute_post_sticky(Payload, State);
        <<"pull_event_sticky">>         -> execute_pull_sticky(Payload, State);
        <<"stack_event_sticky">>        -> execute_stack_sticky(Payload, State);
        <<"unstack_event_sticky">>      -> execute_unstack_sticky(Payload, State);
        <<"groom_event_stack">>         -> execute_groom_stack(Payload, State);
        <<"cluster_event_sticky">>      -> execute_cluster_sticky(Payload, State);
        <<"uncluster_event_sticky">>    -> execute_uncluster_sticky(Payload, State);
        <<"dissolve_event_cluster">>    -> execute_dissolve_cluster(Payload, State);
        <<"name_event_cluster">>        -> execute_name_cluster(Payload, State);
        <<"draw_fact_arrow">>           -> execute_draw_arrow(Payload, State);
        <<"erase_fact_arrow">>          -> execute_erase_arrow(Payload, State);
        <<"promote_event_cluster">>     -> execute_promote_cluster(Payload, State);
        <<"advance_storm_phase">>       -> execute_advance_phase(Payload, State);
        <<"shelve_big_picture_storm">>  -> execute_shelve_storm(Payload, State);
        <<"resume_big_picture_storm">>  -> execute_resume_storm(Payload, State);
        <<"archive_big_picture_storm">> -> execute_archive_storm(Payload, State);
        _ -> {error, unknown_command}
    end;

execute(_State, _Payload) ->
    {error, unknown_command}.

%% --- Command handlers ---

execute_initiate_venture(Payload) ->
    {ok, Cmd} = initiate_venture_v1:from_map(Payload),
    convert_events(maybe_initiate_venture:handle(Cmd), fun venture_initiated_v1:to_map/1).

execute_refine_vision(Payload, #venture_state{status = S}) ->
    case S band ?VL_SUBMITTED of
        0 ->
            {ok, Cmd} = refine_vision_v1:from_map(Payload),
            convert_events(maybe_refine_vision:handle(Cmd), fun vision_refined_v1:to_map/1);
        _ ->
            {error, vision_already_submitted}
    end.

execute_submit_vision(Payload, #venture_state{status = S}) ->
    case S band ?VL_SUBMITTED of
        0 ->
            {ok, Cmd} = submit_vision_v1:from_map(Payload),
            convert_events(maybe_submit_vision:handle(Cmd), fun vision_submitted_v1:to_map/1);
        _ ->
            {error, vision_already_submitted}
    end.

execute_start_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERING of
        0 ->
            case S band ?VL_DISCOVERY_COMPLETED of
                0 ->
                    {ok, Cmd} = start_discovery_v1:from_map(Payload),
                    convert_events(maybe_start_discovery:handle(Cmd), fun discovery_started_v1:to_map/1);
                _ ->
                    {error, discovery_already_completed}
            end;
        _ ->
            {error, discovery_already_started}
    end.

execute_identify_division(Payload, #venture_state{status = S, discovered_divisions = Discovered}) ->
    case S band ?VL_DISCOVERING of
        0 -> {error, discovery_not_active};
        _ ->
            {ok, Cmd} = identify_division_v1:from_map(Payload),
            Context = #{discovered_divisions => Discovered},
            convert_events(maybe_identify_division:handle(Cmd, Context), fun division_identified_v1:to_map/1)
    end.

execute_pause_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERING of
        0 -> {error, discovery_not_active};
        _ ->
            {ok, Cmd} = pause_discovery_v1:from_map(Payload),
            convert_events(maybe_pause_discovery:handle(Cmd), fun discovery_paused_v1:to_map/1)
    end.

execute_resume_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERY_PAUSED of
        0 -> {error, discovery_not_paused};
        _ ->
            {ok, Cmd} = resume_discovery_v1:from_map(Payload),
            convert_events(maybe_resume_discovery:handle(Cmd), fun discovery_resumed_v1:to_map/1)
    end.

execute_complete_discovery(Payload, #venture_state{status = S}) ->
    case S band ?VL_DISCOVERING of
        0 -> {error, discovery_not_active};
        _ ->
            {ok, Cmd} = complete_discovery_v1:from_map(Payload),
            convert_events(maybe_complete_discovery:handle(Cmd), fun discovery_completed_v1:to_map/1)
    end.

execute_archive_venture(Payload, _State) ->
    {ok, Cmd} = archive_venture_v1:from_map(Payload),
    convert_events(maybe_archive_venture:handle(Cmd), fun venture_archived_v1:to_map/1).

execute_scaffold_venture_repo(Payload, #venture_state{status = S}) ->
    %% Guard: must be initiated, vision must not already be submitted
    case S band ?VL_SUBMITTED of
        0 ->
            {ok, Cmd} = scaffold_venture_repo_v1:from_map(Payload),
            convert_events(maybe_scaffold_venture_repo:handle(Cmd), fun venture_repo_scaffolded_v1:to_map/1);
        _ ->
            {error, vision_already_submitted}
    end.

%% --- Big Picture Event Storming command handlers ---

execute_start_storm(Payload, #venture_state{status = S}) ->
    case {S band ?VL_DISCOVERING, S band ?VL_STORMING} of
        {0, _} -> {error, discovery_not_active};
        {_, V} when V =/= 0 -> {error, storm_already_active};
        _ ->
            {ok, Cmd} = start_big_picture_storm_v1:from_map(Payload),
            convert_events(maybe_start_big_picture_storm:handle(Cmd), fun big_picture_storm_started_v1:to_map/1)
    end.

execute_post_sticky(Payload, #venture_state{status = S, storm_number = SN}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = post_event_sticky_v1:from_map(Payload),
        Context = #{storm_number => SN},
        convert_events(maybe_post_event_sticky:handle(Cmd, Context), fun event_sticky_posted_v1:to_map/1)
    end).

execute_pull_sticky(Payload, #venture_state{status = S, event_stickies = Stickies}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = pull_event_sticky_v1:from_map(Payload),
        Context = #{event_stickies => Stickies},
        convert_events(maybe_pull_event_sticky:handle(Cmd, Context), fun event_sticky_pulled_v1:to_map/1)
    end).

execute_stack_sticky(Payload, #venture_state{status = S, event_stickies = Stickies, event_stacks = Stacks}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = stack_event_sticky_v1:from_map(Payload),
        Context = #{event_stickies => Stickies, event_stacks => Stacks},
        maybe_stack_event_sticky:handle(Cmd, Context)
    end).

execute_unstack_sticky(Payload, #venture_state{status = S, event_stickies = Stickies}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = unstack_event_sticky_v1:from_map(Payload),
        Context = #{event_stickies => Stickies},
        convert_events(maybe_unstack_event_sticky:handle(Cmd, Context), fun event_sticky_unstacked_v1:to_map/1)
    end).

execute_groom_stack(Payload, #venture_state{status = S, event_stickies = Stickies, event_stacks = Stacks}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = groom_event_stack_v1:from_map(Payload),
        Context = #{event_stickies => Stickies, event_stacks => Stacks},
        convert_events(maybe_groom_event_stack:handle(Cmd, Context), fun event_stack_groomed_v1:to_map/1)
    end).

execute_cluster_sticky(Payload, #venture_state{status = S, event_stickies = Stickies, event_clusters = Clusters}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = cluster_event_sticky_v1:from_map(Payload),
        Context = #{event_stickies => Stickies, event_clusters => Clusters},
        maybe_cluster_event_sticky:handle(Cmd, Context)
    end).

execute_uncluster_sticky(Payload, #venture_state{status = S, event_stickies = Stickies}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = uncluster_event_sticky_v1:from_map(Payload),
        Context = #{event_stickies => Stickies},
        maybe_uncluster_event_sticky:handle(Cmd, Context)
    end).

execute_dissolve_cluster(Payload, #venture_state{status = S, event_clusters = Clusters}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = dissolve_event_cluster_v1:from_map(Payload),
        Context = #{event_clusters => Clusters},
        maybe_dissolve_event_cluster:handle(Cmd, Context)
    end).

execute_name_cluster(Payload, #venture_state{status = S, event_clusters = Clusters}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = name_event_cluster_v1:from_map(Payload),
        Context = #{event_clusters => Clusters},
        maybe_name_event_cluster:handle(Cmd, Context)
    end).

execute_draw_arrow(Payload, #venture_state{status = S, storm_number = SN, event_clusters = Clusters, fact_arrows = Arrows}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = draw_fact_arrow_v1:from_map(Payload),
        Context = #{storm_number => SN, event_clusters => Clusters, fact_arrows => Arrows},
        maybe_draw_fact_arrow:handle(Cmd, Context)
    end).

execute_erase_arrow(Payload, #venture_state{status = S, fact_arrows = Arrows}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = erase_fact_arrow_v1:from_map(Payload),
        Context = #{fact_arrows => Arrows},
        maybe_erase_fact_arrow:handle(Cmd, Context)
    end).

execute_promote_cluster(Payload, #venture_state{status = S, event_clusters = Clusters}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = promote_event_cluster_v1:from_map(Payload),
        Context = #{event_clusters => Clusters},
        maybe_promote_event_cluster:handle(Cmd, Context)
    end).

execute_advance_phase(Payload, #venture_state{status = S, storm_phase = Phase}) ->
    require_storming(S, fun() ->
        {ok, Cmd} = advance_storm_phase_v1:from_map(Payload),
        Context = #{storm_phase => Phase},
        convert_events(maybe_advance_storm_phase:handle(Cmd, Context), fun storm_phase_advanced_v1:to_map/1)
    end).

execute_shelve_storm(Payload, #venture_state{status = S}) ->
    case S band ?VL_STORMING of
        0 -> {error, storm_not_active};
        _ ->
            {ok, Cmd} = shelve_big_picture_storm_v1:from_map(Payload),
            convert_events(maybe_shelve_big_picture_storm:handle(Cmd), fun big_picture_storm_shelved_v1:to_map/1)
    end.

execute_resume_storm(Payload, #venture_state{status = S}) ->
    case S band ?VL_STORM_SHELVED of
        0 -> {error, storm_not_shelved};
        _ ->
            {ok, Cmd} = resume_big_picture_storm_v1:from_map(Payload),
            convert_events(maybe_resume_big_picture_storm:handle(Cmd), fun big_picture_storm_resumed_v1:to_map/1)
    end.

execute_archive_storm(Payload, #venture_state{status = S}) ->
    case S band ?VL_STORMING bor S band ?VL_STORM_SHELVED of
        0 -> {error, no_storm_to_archive};
        _ ->
            {ok, Cmd} = archive_big_picture_storm_v1:from_map(Payload),
            convert_events(maybe_archive_big_picture_storm:handle(Cmd), fun big_picture_storm_archived_v1:to_map/1)
    end.

require_storming(S, Fun) ->
    case S band ?VL_STORMING of
        0 -> {error, storm_not_active};
        _ -> Fun()
    end.

%% --- Apply ---
%% NOTE: evoq calls apply(State, Event) - State FIRST!

-spec apply(state(), map()) -> state().
apply(State, Event) ->
    apply_event(Event, State).

-spec apply_event(map(), state()) -> state().

%% Inception events
apply_event(#{<<"event_type">> := <<"venture_initiated_v1">>} = E, S) -> apply_initiated(E, S);
apply_event(#{event_type := <<"venture_initiated_v1">>} = E, S)      -> apply_initiated(E, S);
apply_event(#{<<"event_type">> := <<"vision_refined_v1">>} = E, S)   -> apply_vision_refined(E, S);
apply_event(#{event_type := <<"vision_refined_v1">>} = E, S)         -> apply_vision_refined(E, S);
apply_event(#{<<"event_type">> := <<"vision_submitted_v1">>} = E, S) -> apply_vision_submitted(E, S);
apply_event(#{event_type := <<"vision_submitted_v1">>} = E, S)       -> apply_vision_submitted(E, S);
apply_event(#{<<"event_type">> := <<"venture_repo_scaffolded_v1">>} = E, S) -> apply_repo_scaffolded(E, S);
apply_event(#{event_type := <<"venture_repo_scaffolded_v1">>} = E, S)       -> apply_repo_scaffolded(E, S);

%% Discovery events
apply_event(#{<<"event_type">> := <<"discovery_started_v1">>} = E, S)   -> apply_discovery_started(E, S);
apply_event(#{event_type := <<"discovery_started_v1">>} = E, S)         -> apply_discovery_started(E, S);
apply_event(#{<<"event_type">> := <<"division_identified_v1">>} = E, S) -> apply_division_identified(E, S);
apply_event(#{event_type := <<"division_identified_v1">>} = E, S)       -> apply_division_identified(E, S);
apply_event(#{<<"event_type">> := <<"discovery_paused_v1">>} = E, S)    -> apply_discovery_paused(E, S);
apply_event(#{event_type := <<"discovery_paused_v1">>} = E, S)          -> apply_discovery_paused(E, S);
apply_event(#{<<"event_type">> := <<"discovery_resumed_v1">>} = _E, S)  -> apply_discovery_resumed(S);
apply_event(#{event_type := <<"discovery_resumed_v1">>} = _E, S)        -> apply_discovery_resumed(S);
apply_event(#{<<"event_type">> := <<"discovery_completed_v1">>} = E, S) -> apply_discovery_completed(E, S);
apply_event(#{event_type := <<"discovery_completed_v1">>} = E, S)       -> apply_discovery_completed(E, S);

%% Archive
apply_event(#{<<"event_type">> := <<"venture_archived_v1">>} = _E, S) -> apply_archived(S);
apply_event(#{event_type := <<"venture_archived_v1">>} = _E, S)       -> apply_archived(S);

%% Big Picture Event Storming events
apply_event(#{<<"event_type">> := <<"big_picture_storm_started_v1">>} = E, S)  -> apply_storm_started(E, S);
apply_event(#{event_type := <<"big_picture_storm_started_v1">>} = E, S)        -> apply_storm_started(E, S);
apply_event(#{<<"event_type">> := <<"event_sticky_posted_v1">>} = E, S)        -> apply_sticky_posted(E, S);
apply_event(#{event_type := <<"event_sticky_posted_v1">>} = E, S)              -> apply_sticky_posted(E, S);
apply_event(#{<<"event_type">> := <<"event_sticky_pulled_v1">>} = E, S)        -> apply_sticky_pulled(E, S);
apply_event(#{event_type := <<"event_sticky_pulled_v1">>} = E, S)              -> apply_sticky_pulled(E, S);
apply_event(#{<<"event_type">> := <<"event_stack_emerged_v1">>} = E, S)        -> apply_stack_emerged(E, S);
apply_event(#{event_type := <<"event_stack_emerged_v1">>} = E, S)              -> apply_stack_emerged(E, S);
apply_event(#{<<"event_type">> := <<"event_sticky_stacked_v1">>} = E, S)       -> apply_sticky_stacked(E, S);
apply_event(#{event_type := <<"event_sticky_stacked_v1">>} = E, S)             -> apply_sticky_stacked(E, S);
apply_event(#{<<"event_type">> := <<"event_sticky_unstacked_v1">>} = E, S)     -> apply_sticky_unstacked(E, S);
apply_event(#{event_type := <<"event_sticky_unstacked_v1">>} = E, S)           -> apply_sticky_unstacked(E, S);
apply_event(#{<<"event_type">> := <<"event_stack_groomed_v1">>} = E, S)        -> apply_stack_groomed(E, S);
apply_event(#{event_type := <<"event_stack_groomed_v1">>} = E, S)              -> apply_stack_groomed(E, S);
apply_event(#{<<"event_type">> := <<"event_cluster_emerged_v1">>} = E, S)      -> apply_cluster_emerged(E, S);
apply_event(#{event_type := <<"event_cluster_emerged_v1">>} = E, S)            -> apply_cluster_emerged(E, S);
apply_event(#{<<"event_type">> := <<"event_sticky_clustered_v1">>} = E, S)     -> apply_sticky_clustered(E, S);
apply_event(#{event_type := <<"event_sticky_clustered_v1">>} = E, S)           -> apply_sticky_clustered(E, S);
apply_event(#{<<"event_type">> := <<"event_sticky_unclustered_v1">>} = E, S)   -> apply_sticky_unclustered(E, S);
apply_event(#{event_type := <<"event_sticky_unclustered_v1">>} = E, S)         -> apply_sticky_unclustered(E, S);
apply_event(#{<<"event_type">> := <<"event_cluster_dissolved_v1">>} = E, S)    -> apply_cluster_dissolved(E, S);
apply_event(#{event_type := <<"event_cluster_dissolved_v1">>} = E, S)          -> apply_cluster_dissolved(E, S);
apply_event(#{<<"event_type">> := <<"event_cluster_named_v1">>} = E, S)        -> apply_cluster_named(E, S);
apply_event(#{event_type := <<"event_cluster_named_v1">>} = E, S)              -> apply_cluster_named(E, S);
apply_event(#{<<"event_type">> := <<"fact_arrow_drawn_v1">>} = E, S)           -> apply_arrow_drawn(E, S);
apply_event(#{event_type := <<"fact_arrow_drawn_v1">>} = E, S)                 -> apply_arrow_drawn(E, S);
apply_event(#{<<"event_type">> := <<"fact_arrow_erased_v1">>} = E, S)          -> apply_arrow_erased(E, S);
apply_event(#{event_type := <<"fact_arrow_erased_v1">>} = E, S)                -> apply_arrow_erased(E, S);
apply_event(#{<<"event_type">> := <<"event_cluster_promoted_v1">>} = E, S)     -> apply_cluster_promoted(E, S);
apply_event(#{event_type := <<"event_cluster_promoted_v1">>} = E, S)           -> apply_cluster_promoted(E, S);
apply_event(#{<<"event_type">> := <<"storm_phase_advanced_v1">>} = E, S)       -> apply_phase_advanced(E, S);
apply_event(#{event_type := <<"storm_phase_advanced_v1">>} = E, S)             -> apply_phase_advanced(E, S);
apply_event(#{<<"event_type">> := <<"big_picture_storm_shelved_v1">>} = E, S)  -> apply_storm_shelved(E, S);
apply_event(#{event_type := <<"big_picture_storm_shelved_v1">>} = E, S)        -> apply_storm_shelved(E, S);
apply_event(#{<<"event_type">> := <<"big_picture_storm_resumed_v1">>} = _E, S) -> apply_storm_resumed(S);
apply_event(#{event_type := <<"big_picture_storm_resumed_v1">>} = _E, S)       -> apply_storm_resumed(S);
apply_event(#{<<"event_type">> := <<"big_picture_storm_archived_v1">>} = _E, S) -> apply_storm_archived(S);
apply_event(#{event_type := <<"big_picture_storm_archived_v1">>} = _E, S)       -> apply_storm_archived(S);

%% Unknown — ignore
apply_event(_E, S) -> S.

%% --- Apply helpers ---

apply_initiated(E, State) ->
    State#venture_state{
        venture_id = get_value(venture_id, E),
        name = get_value(name, E),
        brief = get_value(brief, E),
        status = evoq_bit_flags:set(0, ?VL_INITIATED),
        repos = get_value(repos, E, []),
        skills = get_value(skills, E, []),
        context_map = get_value(context_map, E, #{}),
        initiated_at = get_value(initiated_at, E),
        initiated_by = get_value(initiated_by, E)
    }.

apply_vision_refined(E, #venture_state{status = Status} = State) ->
    S1 = maybe_update(brief, E, State),
    S2 = maybe_update(repos, E, S1),
    S3 = maybe_update(skills, E, S2),
    S4 = maybe_update(context_map, E, S3),
    S4#venture_state{status = evoq_bit_flags:set(Status, ?VL_VISION_REFINED)}.

apply_vision_submitted(_E, #venture_state{status = Status} = State) ->
    State#venture_state{status = evoq_bit_flags:set(Status, ?VL_SUBMITTED)}.

apply_repo_scaffolded(E, #venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:set(Status, ?VL_VISION_REFINED),
    S1 = evoq_bit_flags:set(S0, ?VL_SUBMITTED),
    Brief = get_value(brief, E),
    State1 = case Brief of
        undefined -> State;
        _ -> State#venture_state{brief = Brief}
    end,
    State1#venture_state{
        status = S1,
        repo_path = get_value(repo_path, E)
    }.

apply_discovery_started(E, #venture_state{status = Status} = State) ->
    State#venture_state{
        status = evoq_bit_flags:set(Status, ?VL_DISCOVERING),
        discovery_started_at = get_value(started_at, E)
    }.

apply_division_identified(E, State) ->
    DivisionId = get_value(division_id, E),
    ContextName = get_value(context_name, E),
    Discovered = State#venture_state.discovered_divisions,
    State#venture_state{
        discovered_divisions = Discovered#{ContextName => DivisionId}
    }.

apply_discovery_paused(E, #venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_DISCOVERING),
    S1 = evoq_bit_flags:set(S0, ?VL_DISCOVERY_PAUSED),
    State#venture_state{
        status = S1,
        discovery_paused_at = get_value(paused_at, E),
        discovery_pause_reason = get_value(reason, E)
    }.

apply_discovery_resumed(#venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_DISCOVERY_PAUSED),
    S1 = evoq_bit_flags:set(S0, ?VL_DISCOVERING),
    State#venture_state{
        status = S1,
        discovery_paused_at = undefined,
        discovery_pause_reason = undefined
    }.

apply_discovery_completed(E, #venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_DISCOVERING),
    S1 = evoq_bit_flags:set(S0, ?VL_DISCOVERY_COMPLETED),
    State#venture_state{
        status = S1,
        discovery_completed_at = get_value(completed_at, E)
    }.

apply_archived(#venture_state{status = Status} = State) ->
    State#venture_state{status = evoq_bit_flags:set(Status, ?VL_ARCHIVED)}.

%% --- Big Picture Event Storming apply helpers ---

apply_storm_started(E, #venture_state{status = Status} = State) ->
    SN = get_value(storm_number, E, 0),
    State#venture_state{
        status = evoq_bit_flags:set(Status, ?VL_STORMING),
        storm_number = SN,
        storm_phase = storm,
        storm_started_at = get_value(started_at, E),
        storm_shelved_at = undefined,
        event_stickies = #{},
        event_stacks = #{},
        event_clusters = #{},
        fact_arrows = #{}
    }.

apply_sticky_posted(E, #venture_state{event_stickies = Stickies} = State) ->
    StickyId = get_value(sticky_id, E),
    Sticky = #{
        text => get_value(text, E),
        author => get_value(author, E, <<"user">>),
        weight => 1,
        stack_id => undefined,
        cluster_id => undefined,
        created_at => get_value(created_at, E)
    },
    State#venture_state{event_stickies = Stickies#{StickyId => Sticky}}.

apply_sticky_pulled(E, #venture_state{event_stickies = Stickies} = State) ->
    StickyId = get_value(sticky_id, E),
    State#venture_state{event_stickies = maps:remove(StickyId, Stickies)}.

apply_stack_emerged(E, #venture_state{event_stacks = Stacks} = State) ->
    StackId = get_value(stack_id, E),
    Stack = #{
        color => get_value(color, E),
        sticky_ids => []  %% stacked events populate this
    },
    State#venture_state{event_stacks = Stacks#{StackId => Stack}}.

apply_sticky_stacked(E, #venture_state{event_stickies = Stickies, event_stacks = Stacks} = State) ->
    StickyId = get_value(sticky_id, E),
    StackId = get_value(stack_id, E),
    Stickies1 = case maps:find(StickyId, Stickies) of
        {ok, S} -> Stickies#{StickyId => S#{stack_id => StackId}};
        error -> Stickies
    end,
    Stacks1 = case maps:find(StackId, Stacks) of
        {ok, Stk} ->
            Ids = maps:get(sticky_ids, Stk, []),
            Stacks#{StackId => Stk#{sticky_ids => [StickyId | Ids]}};
        error -> Stacks
    end,
    State#venture_state{event_stickies = Stickies1, event_stacks = Stacks1}.

apply_sticky_unstacked(E, #venture_state{event_stickies = Stickies, event_stacks = Stacks} = State) ->
    StickyId = get_value(sticky_id, E),
    StackId = get_value(stack_id, E),
    Stickies1 = case maps:find(StickyId, Stickies) of
        {ok, S} -> Stickies#{StickyId => S#{stack_id => undefined}};
        error -> Stickies
    end,
    Stacks1 = case maps:find(StackId, Stacks) of
        {ok, Stk} ->
            Ids = lists:delete(StickyId, maps:get(sticky_ids, Stk, [])),
            Stacks#{StackId => Stk#{sticky_ids => Ids}};
        error -> Stacks
    end,
    State#venture_state{event_stickies = Stickies1, event_stacks = Stacks1}.

apply_stack_groomed(E, #venture_state{event_stickies = Stickies, event_stacks = Stacks} = State) ->
    StackId = get_value(stack_id, E),
    CanonicalId = get_value(canonical_sticky_id, E),
    Weight = get_value(weight, E, 1),
    AbsorbedIds = get_value(absorbed_sticky_ids, E, []),
    %% Update canonical sticky weight and clear stack_id
    Stickies1 = case maps:find(CanonicalId, Stickies) of
        {ok, S} -> Stickies#{CanonicalId => S#{weight => Weight, stack_id => undefined}};
        error -> Stickies
    end,
    %% Remove absorbed stickies
    Stickies2 = lists:foldl(fun(Id, Acc) -> maps:remove(Id, Acc) end, Stickies1, AbsorbedIds),
    %% Remove the stack
    Stacks1 = maps:remove(StackId, Stacks),
    State#venture_state{event_stickies = Stickies2, event_stacks = Stacks1}.

apply_cluster_emerged(E, #venture_state{event_clusters = Clusters} = State) ->
    ClusterId = get_value(cluster_id, E),
    Cluster = #{
        name => undefined,
        color => get_value(color, E),
        sticky_ids => [],  %% clustered events populate this
        status => active
    },
    State#venture_state{event_clusters = Clusters#{ClusterId => Cluster}}.

apply_sticky_clustered(E, #venture_state{event_stickies = Stickies, event_clusters = Clusters} = State) ->
    StickyId = get_value(sticky_id, E),
    ClusterId = get_value(cluster_id, E),
    Stickies1 = case maps:find(StickyId, Stickies) of
        {ok, S} -> Stickies#{StickyId => S#{cluster_id => ClusterId}};
        error -> Stickies
    end,
    Clusters1 = case maps:find(ClusterId, Clusters) of
        {ok, C} ->
            Ids = maps:get(sticky_ids, C, []),
            Clusters#{ClusterId => C#{sticky_ids => [StickyId | Ids]}};
        error -> Clusters
    end,
    State#venture_state{event_stickies = Stickies1, event_clusters = Clusters1}.

apply_sticky_unclustered(E, #venture_state{event_stickies = Stickies, event_clusters = Clusters} = State) ->
    StickyId = get_value(sticky_id, E),
    ClusterId = get_value(cluster_id, E),
    Stickies1 = case maps:find(StickyId, Stickies) of
        {ok, S} -> Stickies#{StickyId => S#{cluster_id => undefined}};
        error -> Stickies
    end,
    Clusters1 = case maps:find(ClusterId, Clusters) of
        {ok, C} ->
            Ids = lists:delete(StickyId, maps:get(sticky_ids, C, [])),
            Clusters#{ClusterId => C#{sticky_ids => Ids}};
        error -> Clusters
    end,
    State#venture_state{event_stickies = Stickies1, event_clusters = Clusters1}.

apply_cluster_dissolved(E, #venture_state{event_stickies = Stickies, event_clusters = Clusters} = State) ->
    ClusterId = get_value(cluster_id, E),
    %% Uncluster all stickies in this cluster
    StickyIds = case maps:find(ClusterId, Clusters) of
        {ok, C} -> maps:get(sticky_ids, C, []);
        error -> []
    end,
    Stickies1 = lists:foldl(fun(Id, Acc) ->
        case maps:find(Id, Acc) of
            {ok, S} -> Acc#{Id => S#{cluster_id => undefined}};
            error -> Acc
        end
    end, Stickies, StickyIds),
    Clusters1 = case maps:find(ClusterId, Clusters) of
        {ok, C2} -> Clusters#{ClusterId => C2#{status => dissolved, sticky_ids => []}};
        error -> Clusters
    end,
    State#venture_state{event_stickies = Stickies1, event_clusters = Clusters1}.

apply_cluster_named(E, #venture_state{event_clusters = Clusters} = State) ->
    ClusterId = get_value(cluster_id, E),
    Name = get_value(name, E),
    Clusters1 = case maps:find(ClusterId, Clusters) of
        {ok, C} -> Clusters#{ClusterId => C#{name => Name}};
        error -> Clusters
    end,
    State#venture_state{event_clusters = Clusters1}.

apply_arrow_drawn(E, #venture_state{fact_arrows = Arrows} = State) ->
    ArrowId = get_value(arrow_id, E),
    Arrow = #{
        from_cluster => get_value(from_cluster, E),
        to_cluster => get_value(to_cluster, E),
        fact_name => get_value(fact_name, E)
    },
    State#venture_state{fact_arrows = Arrows#{ArrowId => Arrow}}.

apply_arrow_erased(E, #venture_state{fact_arrows = Arrows} = State) ->
    ArrowId = get_value(arrow_id, E),
    State#venture_state{fact_arrows = maps:remove(ArrowId, Arrows)}.

apply_cluster_promoted(E, #venture_state{event_clusters = Clusters} = State) ->
    ClusterId = get_value(cluster_id, E),
    Clusters1 = case maps:find(ClusterId, Clusters) of
        {ok, C} -> Clusters#{ClusterId => C#{status => promoted}};
        error -> Clusters
    end,
    State#venture_state{event_clusters = Clusters1}.

apply_phase_advanced(E, State) ->
    Phase = get_value(phase, E),
    PhaseAtom = case Phase of
        <<"storm">> -> storm;
        <<"stack">> -> stack;
        <<"groom">> -> groom;
        <<"cluster">> -> cluster;
        <<"name">> -> name;
        <<"map">> -> map;
        <<"promoted">> -> promoted;
        _ -> undefined
    end,
    State#venture_state{storm_phase = PhaseAtom}.

apply_storm_shelved(E, #venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_STORMING),
    S1 = evoq_bit_flags:set(S0, ?VL_STORM_SHELVED),
    State#venture_state{
        status = S1,
        storm_phase = shelved,
        storm_shelved_at = get_value(shelved_at, E)
    }.

apply_storm_resumed(#venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_STORM_SHELVED),
    S1 = evoq_bit_flags:set(S0, ?VL_STORMING),
    State#venture_state{
        status = S1,
        storm_phase = storm,
        storm_shelved_at = undefined
    }.

apply_storm_archived(#venture_state{status = Status} = State) ->
    S0 = evoq_bit_flags:unset(Status, ?VL_STORMING),
    S1 = evoq_bit_flags:unset(S0, ?VL_STORM_SHELVED),
    State#venture_state{
        status = S1,
        storm_phase = undefined,
        storm_started_at = undefined,
        storm_shelved_at = undefined,
        event_stickies = #{},
        event_stacks = #{},
        event_clusters = #{},
        fact_arrows = #{}
    }.

%% --- Internal ---

maybe_update(Field, E, State) ->
    case get_value(Field, E) of
        undefined -> State;
        Value -> set_field(Field, Value, State)
    end.

set_field(brief, V, S) -> S#venture_state{brief = V};
set_field(repos, V, S) -> S#venture_state{repos = V};
set_field(skills, V, S) -> S#venture_state{skills = V};
set_field(context_map, V, S) -> S#venture_state{context_map = V}.

get_command_type(#{<<"command_type">> := T}) -> T;
get_command_type(#{command_type := T}) when is_binary(T) -> T;
get_command_type(#{command_type := T}) when is_atom(T) -> atom_to_binary(T);
get_command_type(_) -> undefined.

get_value(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, undefined)
    end.

get_value(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key), Map, Default)
    end.

convert_events({ok, Events}, ToMapFn) ->
    {ok, [ToMapFn(E) || E <- Events]};
convert_events({error, _} = Err, _) ->
    Err.
