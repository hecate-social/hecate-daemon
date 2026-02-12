%%% @doc Tests for venture lifecycle handlers (maybe_*.erl modules).
%%%
%%% Tests each handler's validation logic and event creation in isolation.
%%% Pure function tests — no external deps.
-module(venture_handler_tests).

-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Test generators
%% ===================================================================

handler_test_() ->
    [
        %% maybe_initiate_venture
        {"initiate: valid name succeeds",           fun initiate_valid/0},
        {"initiate: empty name fails",              fun initiate_empty_name/0},
        {"initiate: missing name fails",            fun initiate_missing_name/0},
        {"initiate: event has correct fields",      fun initiate_event_fields/0},
        {"initiate: auto-generates venture_id",     fun initiate_auto_id/0},

        %% maybe_refine_vision
        {"refine: valid venture_id succeeds",       fun refine_valid/0},
        {"refine: empty venture_id fails",          fun refine_empty_id/0},
        {"refine: event carries optional fields",   fun refine_event_fields/0},

        %% maybe_submit_vision
        {"submit: valid venture_id succeeds",       fun submit_valid/0},
        {"submit: empty venture_id fails",          fun submit_empty_id/0},

        %% maybe_start_discovery
        {"start discovery: valid succeeds",         fun start_discovery_valid/0},
        {"start discovery: empty id fails",         fun start_discovery_empty_id/0},

        %% maybe_identify_division
        {"identify: valid with empty context succeeds", fun identify_valid/0},
        {"identify: duplicate context_name fails",  fun identify_duplicate/0},
        {"identify: empty venture_id fails",        fun identify_empty_venture_id/0},
        {"identify: empty context_name fails",      fun identify_empty_context_name/0},

        %% maybe_pause_discovery
        {"pause: valid with reason succeeds",       fun pause_valid/0},
        {"pause: empty venture_id fails",           fun pause_empty_id/0},

        %% maybe_archive_venture
        {"archive: valid venture_id succeeds",      fun archive_valid/0},
        {"archive: empty venture_id fails",         fun archive_empty_id/0},
        {"archive: event carries reason",           fun archive_event_reason/0}
    ].

%% ===================================================================
%% maybe_initiate_venture
%% ===================================================================

initiate_valid() ->
    {ok, Cmd} = initiate_venture_v1:new(#{name => <<"My Venture">>}),
    {ok, [_Event]} = maybe_initiate_venture:handle(Cmd).

initiate_empty_name() ->
    {ok, Cmd} = initiate_venture_v1:new(#{name => <<>>}),
    ?assertEqual({error, invalid_command}, maybe_initiate_venture:handle(Cmd)).

initiate_missing_name() ->
    ?assertMatch({error, _}, initiate_venture_v1:new(#{})).

initiate_event_fields() ->
    {ok, Cmd} = initiate_venture_v1:new(#{
        name => <<"Test">>,
        venture_id => <<"v-123">>,
        brief => <<"A brief">>,
        initiated_by => <<"user@host">>
    }),
    {ok, [Event]} = maybe_initiate_venture:handle(Cmd),
    Map = venture_initiated_v1:to_map(Event),
    ?assertEqual(<<"v-123">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"Test">>, maps:get(<<"name">>, Map)),
    ?assertEqual(<<"A brief">>, maps:get(<<"brief">>, Map)),
    ?assertEqual(<<"user@host">>, maps:get(<<"initiated_by">>, Map)),
    ?assert(is_integer(maps:get(<<"initiated_at">>, Map))).

initiate_auto_id() ->
    {ok, Cmd} = initiate_venture_v1:new(#{name => <<"Auto ID">>}),
    VentureId = initiate_venture_v1:get_venture_id(Cmd),
    ?assertMatch(<<"venture-", _/binary>>, VentureId).

%% ===================================================================
%% maybe_refine_vision
%% ===================================================================

refine_valid() ->
    {ok, Cmd} = refine_vision_v1:from_map(#{
        <<"venture_id">> => <<"v-123">>,
        <<"brief">> => <<"Updated">>
    }),
    {ok, [_Event]} = maybe_refine_vision:handle(Cmd).

refine_empty_id() ->
    {ok, Cmd} = refine_vision_v1:from_map(#{
        <<"venture_id">> => <<>>,
        <<"brief">> => <<"x">>
    }),
    ?assertEqual({error, invalid_venture_id}, maybe_refine_vision:handle(Cmd)).

refine_event_fields() ->
    {ok, Cmd} = refine_vision_v1:from_map(#{
        <<"venture_id">> => <<"v-456">>,
        <<"brief">> => <<"New brief">>,
        <<"repos">> => [<<"repo1">>, <<"repo2">>],
        <<"skills">> => [<<"erlang">>],
        <<"context_map">> => #{<<"key">> => <<"val">>}
    }),
    {ok, [Event]} = maybe_refine_vision:handle(Cmd),
    Map = vision_refined_v1:to_map(Event),
    ?assertEqual(<<"v-456">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"New brief">>, maps:get(<<"brief">>, Map)),
    ?assertEqual([<<"repo1">>, <<"repo2">>], maps:get(<<"repos">>, Map)),
    ?assertEqual([<<"erlang">>], maps:get(<<"skills">>, Map)).

%% ===================================================================
%% maybe_submit_vision
%% ===================================================================

submit_valid() ->
    {ok, Cmd} = submit_vision_v1:from_map(#{<<"venture_id">> => <<"v-123">>}),
    {ok, [_Event]} = maybe_submit_vision:handle(Cmd).

submit_empty_id() ->
    {ok, Cmd} = submit_vision_v1:from_map(#{<<"venture_id">> => <<>>}),
    ?assertEqual({error, invalid_venture_id}, maybe_submit_vision:handle(Cmd)).

%% ===================================================================
%% maybe_start_discovery
%% ===================================================================

start_discovery_valid() ->
    {ok, Cmd} = start_discovery_v1:new(#{venture_id => <<"v-123">>}),
    {ok, [Event]} = maybe_start_discovery:handle(Cmd),
    Map = discovery_started_v1:to_map(Event),
    ?assertEqual(<<"v-123">>, maps:get(<<"venture_id">>, Map)).

start_discovery_empty_id() ->
    ?assertMatch({error, _}, start_discovery_v1:new(#{venture_id => <<>>})).

%% ===================================================================
%% maybe_identify_division
%% ===================================================================

identify_valid() ->
    {ok, Cmd} = identify_division_v1:new(#{
        venture_id => <<"v-123">>,
        context_name => <<"auth_division">>,
        description => <<"Authentication">>
    }),
    Context = #{discovered_divisions => #{}},
    {ok, [Event]} = maybe_identify_division:handle(Cmd, Context),
    Map = division_identified_v1:to_map(Event),
    ?assertEqual(<<"auth_division">>, maps:get(<<"context_name">>, Map)).

identify_duplicate() ->
    {ok, Cmd} = identify_division_v1:new(#{
        venture_id => <<"v-123">>,
        context_name => <<"auth_division">>
    }),
    Context = #{discovered_divisions => #{<<"auth_division">> => <<"div-1">>}},
    ?assertEqual({error, division_already_identified},
                 maybe_identify_division:handle(Cmd, Context)).

identify_empty_venture_id() ->
    ?assertMatch({error, _},
        identify_division_v1:new(#{venture_id => <<>>, context_name => <<"x">>})).

identify_empty_context_name() ->
    ?assertMatch({error, _},
        identify_division_v1:new(#{venture_id => <<"v-1">>, context_name => <<>>})).

%% ===================================================================
%% maybe_pause_discovery
%% ===================================================================

pause_valid() ->
    {ok, Cmd} = pause_discovery_v1:from_map(#{
        <<"venture_id">> => <<"v-123">>,
        <<"reason">> => <<"blocked on feedback">>
    }),
    {ok, [Event]} = maybe_pause_discovery:handle(Cmd),
    Map = discovery_paused_v1:to_map(Event),
    ?assertEqual(<<"v-123">>, maps:get(<<"venture_id">>, Map)).

pause_empty_id() ->
    ?assertMatch({error, _},
        pause_discovery_v1:from_map(#{<<"venture_id">> => <<>>})).

%% ===================================================================
%% maybe_archive_venture
%% ===================================================================

archive_valid() ->
    {ok, Cmd} = archive_venture_v1:from_map(#{
        <<"venture_id">> => <<"v-123">>,
        <<"reason">> => <<"no longer needed">>
    }),
    {ok, [_Event]} = maybe_archive_venture:handle(Cmd).

archive_empty_id() ->
    {ok, Cmd} = archive_venture_v1:from_map(#{
        <<"venture_id">> => <<>>,
        <<"reason">> => <<"x">>
    }),
    ?assertEqual({error, invalid_venture_id}, maybe_archive_venture:handle(Cmd)).

archive_event_reason() ->
    {ok, Cmd} = archive_venture_v1:from_map(#{
        <<"venture_id">> => <<"v-789">>,
        <<"reason">> => <<"abandoned">>
    }),
    {ok, [Event]} = maybe_archive_venture:handle(Cmd),
    Map = venture_archived_v1:to_map(Event),
    ?assertEqual(<<"v-789">>, maps:get(<<"venture_id">>, Map)),
    ?assertEqual(<<"abandoned">>, maps:get(<<"reason">>, Map)).
