%%% @doc Layer 1: Dossier Tests -- Pure aggregate state reconstruction.
%%% Tests apply/2 chains to verify the dossier (aggregate state)
%%% reconstructs correctly from event sequences. No processes, no I/O.
%%%
%%% Since design_state record is internal to design_aggregate, we verify
%%% state correctness through execute/2 behavior (state machine guards)
%%% and through the behaviour callback apply/2.
-module(design_aggregate_tests).

-include_lib("eunit/include/eunit.hrl").
-include_lib("design_division/include/design_status.hrl").

%% Record field positions in design_state (record tag is element 1)
-define(F_DIVISION_ID,          2).
-define(F_STATUS,               3).
-define(F_DESIGNED_AGGREGATES,  4).
-define(F_DESIGNED_EVENTS,      5).
-define(F_STARTED_AT,           6).
-define(F_PAUSED_AT,            7).
-define(F_COMPLETED_AT,         8).
-define(F_PAUSE_REASON,         9).

%% ===================================================================
%% Test Fixtures (reusable event maps)
%% ===================================================================

start_event() ->
    #{<<"event_type">> => <<"design_started_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"started_at">> => 1000,
      <<"started_by">> => <<"test@host">>}.

design_aggregate_event() ->
    #{<<"event_type">> => <<"aggregate_designed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"aggregate_id">> => <<"agg-001">>,
      <<"aggregate_name">> => <<"order_aggregate">>,
      <<"stream_pattern">> => <<"order-{id}">>,
      <<"status_flags">> => [#{<<"name">> => <<"active">>, <<"bit">> => 1}],
      <<"description">> => <<"Manages orders">>,
      <<"designed_by">> => <<"architect@host">>,
      <<"designed_at">> => 2000}.

design_event_event() ->
    #{<<"event_type">> => <<"event_designed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"event_id">> => <<"evt-001">>,
      <<"event_name">> => <<"order_placed_v1">>,
      <<"aggregate_name">> => <<"order_aggregate">>,
      <<"payload_fields">> => [#{<<"name">> => <<"order_id">>, <<"type">> => <<"binary">>}],
      <<"description">> => <<"Order was placed">>,
      <<"designed_by">> => <<"architect@host">>,
      <<"designed_at">> => 3000}.

pause_event() ->
    #{<<"event_type">> => <<"design_paused_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"paused_at">> => 4000,
      <<"reason">> => <<"waiting for review">>}.

resume_event() ->
    #{<<"event_type">> => <<"design_resumed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"resumed_at">> => 5000}.

complete_event() ->
    #{<<"event_type">> => <<"design_completed_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"completed_at">> => 6000}.

archive_event() ->
    #{<<"event_type">> => <<"design_archived_v1">>,
      <<"division_id">> => <<"div-1">>,
      <<"archived_at">> => 7000,
      <<"archived_by">> => <<"admin@host">>,
      <<"reason">> => <<"test cleanup">>}.

%% ===================================================================
%% Layer 1 Tests: Dossier (Pure Aggregate State)
%% ===================================================================

%% init/1 callback returns {ok, initial_state} with zeroed fields
initial_state_test() ->
    {ok, S} = design_aggregate:init(<<"any-id">>),
    ?assertEqual(undefined, element(?F_DIVISION_ID, S)),
    ?assertEqual(0, element(?F_STATUS, S)),
    ?assertEqual(#{}, element(?F_DESIGNED_AGGREGATES, S)),
    ?assertEqual(#{}, element(?F_DESIGNED_EVENTS, S)),
    ?assertEqual(undefined, element(?F_STARTED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S)),
    ?assertEqual(undefined, element(?F_COMPLETED_AT, S)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S)).

%% init/1 callback returns {ok, State} tuple
init_callback_test() ->
    {ok, S} = design_aggregate:init(<<"div-1">>),
    ?assertEqual(0, element(?F_STATUS, S)).

%% Apply design_started_v1 sets INITIATED + ACTIVE bits, populates fields
apply_start_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    Status = element(?F_STATUS, S1),
    ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
    ?assertNotEqual(0, Status band ?DESIGN_ACTIVE),
    ?assertEqual(0, Status band ?DESIGN_PAUSED),
    ?assertEqual(0, Status band ?DESIGN_COMPLETED),
    ?assertEqual(0, Status band ?DESIGN_ARCHIVED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)),
    ?assertEqual(1000, element(?F_STARTED_AT, S1)).

%% Apply aggregate_designed_v1 adds to designed_aggregates map
apply_design_aggregate_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, design_aggregate_event()),
    Aggregates = element(?F_DESIGNED_AGGREGATES, S2),
    ?assert(maps:is_key(<<"order_aggregate">>, Aggregates)),
    Details = maps:get(<<"order_aggregate">>, Aggregates),
    ?assertEqual(<<"order_aggregate">>, maps:get(aggregate_name, Details)),
    ?assertEqual(<<"Manages orders">>, maps:get(description, Details)).

%% Apply event_designed_v1 adds to designed_events map
apply_design_event_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, design_event_event()),
    Events = element(?F_DESIGNED_EVENTS, S2),
    ?assert(maps:is_key(<<"order_placed_v1">>, Events)),
    Details = maps:get(<<"order_placed_v1">>, Events),
    ?assertEqual(<<"order_placed_v1">>, maps:get(event_name, Details)),
    ?assertEqual(<<"order_aggregate">>, maps:get(aggregate_name, Details)),
    ?assertEqual(<<"Order was placed">>, maps:get(description, Details)).

%% Apply design_paused_v1 clears ACTIVE, sets PAUSED
apply_pause_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, pause_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
    ?assertEqual(0, Status band ?DESIGN_ACTIVE),
    ?assertNotEqual(0, Status band ?DESIGN_PAUSED),
    ?assertEqual(4000, element(?F_PAUSED_AT, S2)),
    ?assertEqual(<<"waiting for review">>, element(?F_PAUSE_REASON, S2)).

%% Apply design_resumed_v1 clears PAUSED, sets ACTIVE
apply_resume_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, pause_event()),
    S3 = design_aggregate:apply(S2, resume_event()),
    Status = element(?F_STATUS, S3),
    ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
    ?assertNotEqual(0, Status band ?DESIGN_ACTIVE),
    ?assertEqual(0, Status band ?DESIGN_PAUSED),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).

%% Apply design_completed_v1 clears ACTIVE, sets COMPLETED
apply_complete_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, complete_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
    ?assertEqual(0, Status band ?DESIGN_ACTIVE),
    ?assertNotEqual(0, Status band ?DESIGN_COMPLETED),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S2)).

%% Apply design_archived_v1 sets ARCHIVED bit
apply_archive_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, archive_event()),
    Status = element(?F_STATUS, S2),
    ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
    ?assertNotEqual(0, Status band ?DESIGN_ARCHIVED).

%% Full lifecycle: start -> design_aggregate -> design_event -> pause -> resume -> complete -> archive
full_lifecycle_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, design_aggregate_event()),
    S3 = design_aggregate:apply(S2, design_event_event()),
    S4 = design_aggregate:apply(S3, pause_event()),
    S5 = design_aggregate:apply(S4, resume_event()),
    S6 = design_aggregate:apply(S5, complete_event()),
    S7 = design_aggregate:apply(S6, archive_event()),
    Status = element(?F_STATUS, S7),
    ?assertNotEqual(0, Status band ?DESIGN_INITIATED),
    ?assertEqual(0, Status band ?DESIGN_ACTIVE),
    ?assertEqual(0, Status band ?DESIGN_PAUSED),
    ?assertNotEqual(0, Status band ?DESIGN_COMPLETED),
    ?assertNotEqual(0, Status band ?DESIGN_ARCHIVED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S7)),
    %% Aggregates and events are populated
    ?assertEqual(1, maps:size(element(?F_DESIGNED_AGGREGATES, S7))),
    ?assertEqual(1, maps:size(element(?F_DESIGNED_EVENTS, S7))),
    ?assertEqual(6000, element(?F_COMPLETED_AT, S7)).

%% Unknown event leaves state unchanged
unknown_event_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    Unknown = #{<<"event_type">> => <<"some_random_event">>, <<"data">> => <<"whatever">>},
    S2 = design_aggregate:apply(S1, Unknown),
    ?assertEqual(S1, S2).

%% Events with atom keys work identically to binary keys
atom_keys_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    AtomEvent = #{event_type => <<"design_started_v1">>,
                  division_id => <<"div-atom">>,
                  started_at => 9000,
                  started_by => <<"atom@host">>},
    S1 = design_aggregate:apply(S0, AtomEvent),
    ?assertEqual(<<"div-atom">>, element(?F_DIVISION_ID, S1)),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DESIGN_INITIATED),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DESIGN_ACTIVE),
    ?assertEqual(9000, element(?F_STARTED_AT, S1)).

%% Flag map macro returns expected labels
flag_map_test() ->
    Map = ?DESIGN_FLAG_MAP,
    ?assertEqual(<<"Initiated">>, maps:get(?DESIGN_INITIATED, Map)),
    ?assertEqual(<<"Active">>, maps:get(?DESIGN_ACTIVE, Map)),
    ?assertEqual(<<"Paused">>, maps:get(?DESIGN_PAUSED, Map)),
    ?assertEqual(<<"Completed">>, maps:get(?DESIGN_COMPLETED, Map)),
    ?assertEqual(<<"Archived">>, maps:get(?DESIGN_ARCHIVED, Map)).

%% Behaviour callback: apply/2 takes (State, Event) -- state first
callback_order_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    ?assertNotEqual(0, element(?F_STATUS, S1) band ?DESIGN_INITIATED),
    ?assertEqual(<<"div-1">>, element(?F_DIVISION_ID, S1)).

%% Multiple aggregates can be designed
multiple_aggregates_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    Agg1 = design_aggregate_event(),
    Agg2 = Agg1#{<<"aggregate_name">> => <<"payment_aggregate">>,
                  <<"aggregate_id">> => <<"agg-002">>,
                  <<"description">> => <<"Manages payments">>},
    S2 = design_aggregate:apply(S1, Agg1),
    S3 = design_aggregate:apply(S2, Agg2),
    Aggregates = element(?F_DESIGNED_AGGREGATES, S3),
    ?assertEqual(2, maps:size(Aggregates)),
    ?assert(maps:is_key(<<"order_aggregate">>, Aggregates)),
    ?assert(maps:is_key(<<"payment_aggregate">>, Aggregates)).

%% Multiple events can be designed
multiple_events_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    Evt1 = design_event_event(),
    Evt2 = Evt1#{<<"event_name">> => <<"order_shipped_v1">>,
                  <<"event_id">> => <<"evt-002">>,
                  <<"description">> => <<"Order shipped">>},
    S2 = design_aggregate:apply(S1, Evt1),
    S3 = design_aggregate:apply(S2, Evt2),
    Events = element(?F_DESIGNED_EVENTS, S3),
    ?assertEqual(2, maps:size(Events)),
    ?assert(maps:is_key(<<"order_placed_v1">>, Events)),
    ?assert(maps:is_key(<<"order_shipped_v1">>, Events)).

%% Pause -> resume clears pause metadata
pause_resume_clears_metadata_test() ->
    {ok, S0} = design_aggregate:init(<<"div-1">>),
    S1 = design_aggregate:apply(S0, start_event()),
    S2 = design_aggregate:apply(S1, pause_event()),
    ?assertNotEqual(undefined, element(?F_PAUSED_AT, S2)),
    ?assertNotEqual(undefined, element(?F_PAUSE_REASON, S2)),
    S3 = design_aggregate:apply(S2, resume_event()),
    ?assertEqual(undefined, element(?F_PAUSED_AT, S3)),
    ?assertEqual(undefined, element(?F_PAUSE_REASON, S3)).
