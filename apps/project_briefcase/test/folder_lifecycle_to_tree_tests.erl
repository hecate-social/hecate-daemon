%%% @doc Tests for folder_lifecycle_to_tree merged projection.
%%%
%%% Verifies that folder lifecycle events correctly update the
%%% briefcase_folder_tree ETS read model.
%%% @end
-module(folder_lifecycle_to_tree_tests).

-include_lib("eunit/include/eunit.hrl").

-define(TABLE, briefcase_folder_tree).
-define(FOLDER_ID, <<"folder-001">>).
-define(PARENT_ID, <<"folder-root">>).

%% -- Setup / Teardown --

setup() ->
    ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    RM.

cleanup(RM) ->
    catch ets:delete(?TABLE),
    RM.

%% -- Helpers --

make_folder_initiated_event() ->
    #{
        event_type => <<"folder_initiated_v1">>,
        folder_id  => ?FOLDER_ID,
        name       => <<"Documents">>,
        parent_id  => ?PARENT_ID,
        icon       => <<"folder">>,
        created_at => erlang:system_time(millisecond)
    }.

make_folder_renamed_event() ->
    #{
        event_type => <<"folder_renamed_v1">>,
        folder_id  => ?FOLDER_ID,
        name       => <<"My Documents">>,
        renamed_at => erlang:system_time(millisecond)
    }.

make_folder_moved_event() ->
    #{
        event_type => <<"folder_moved_v1">>,
        folder_id  => ?FOLDER_ID,
        parent_id  => <<"folder-archive">>,
        moved_at   => erlang:system_time(millisecond)
    }.

make_folder_archived_event() ->
    #{
        event_type  => <<"folder_archived_v1">>,
        folder_id   => ?FOLDER_ID,
        archived_at => erlang:system_time(millisecond)
    }.

wrap_event(Data) ->
    #{data => Data, event_type => maps:get(event_type, Data)}.

project(Data, State, RM) ->
    folder_lifecycle_to_tree:project(wrap_event(Data), #{}, State, RM).

%% ===================================================================
%% Folder Initiated
%% ===================================================================

folder_initiated_projects_to_tree_test() ->
    RM = setup(),
    try
        {ok, _S, _RM1} = project(make_folder_initiated_event(), #{}, RM),
        {ok, Folder} = project_briefcase_store:get_folder(?FOLDER_ID),
        ?assertEqual(?FOLDER_ID, maps:get(folder_id, Folder)),
        ?assertEqual(<<"Documents">>, maps:get(name, Folder)),
        ?assertEqual(?PARENT_ID, maps:get(parent_id, Folder)),
        ?assertEqual(<<"folder">>, maps:get(icon, Folder)),
        ?assertEqual(1, maps:get(status, Folder)),
        ?assert(is_integer(maps:get(created_at, Folder))),
        ?assertEqual(maps:get(created_at, Folder), maps:get(updated_at, Folder))
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Folder Renamed
%% ===================================================================

folder_renamed_updates_name_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_folder_initiated_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_folder_renamed_event(), S1, RM1),
        {ok, Folder} = project_briefcase_store:get_folder(?FOLDER_ID),
        ?assertEqual(<<"My Documents">>, maps:get(name, Folder)),
        %% Status should have RENAMED flag (bit 1 = 2)
        ?assertNotEqual(0, maps:get(status, Folder) band 2)
    after
        cleanup(RM)
    end.

folder_renamed_before_initiate_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_folder_renamed_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Folder Moved
%% ===================================================================

folder_moved_updates_parent_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_folder_initiated_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_folder_moved_event(), S1, RM1),
        {ok, Folder} = project_briefcase_store:get_folder(?FOLDER_ID),
        ?assertEqual(<<"folder-archive">>, maps:get(parent_id, Folder)),
        %% Status should have MOVED flag (bit 2 = 4)
        ?assertNotEqual(0, maps:get(status, Folder) band 4)
    after
        cleanup(RM)
    end.

folder_moved_before_initiate_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_folder_moved_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Folder Archived
%% ===================================================================

folder_archived_removes_from_tree_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_folder_initiated_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_folder_archived_event(), S1, RM1),
        ?assertEqual({error, not_found}, project_briefcase_store:get_folder(?FOLDER_ID))
    after
        cleanup(RM)
    end.

folder_archived_before_initiate_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_folder_archived_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Unknown Event
%% ===================================================================

unknown_event_skips_test() ->
    RM = setup(),
    try
        Event = #{event_type => <<"folder_exploded_v1">>, data => #{}},
        {skip, _S, _RM1} = folder_lifecycle_to_tree:project(Event, #{}, #{}, RM)
    after
        cleanup(RM)
    end.
