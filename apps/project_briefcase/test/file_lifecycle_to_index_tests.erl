%%% @doc Tests for file_lifecycle_to_index merged projection.
%%%
%%% Verifies that file lifecycle events correctly update the
%%% briefcase_file_index ETS read model.
%%% @end
-module(file_lifecycle_to_index_tests).

-include_lib("eunit/include/eunit.hrl").

-define(FILE_TABLE, briefcase_file_index).
-define(FOLDER_TABLE, briefcase_folder_tree).
-define(FILE_ID, <<"file-001">>).
-define(FOLDER_ID, <<"folder-001">>).

%% -- Setup / Teardown --

setup() ->
    %% file projection writes via project_briefcase_store which uses the named tables directly
    ets:new(?FILE_TABLE, [set, public, named_table, {read_concurrency, true}]),
    ets:new(?FOLDER_TABLE, [set, public, named_table, {read_concurrency, true}]),
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?FILE_TABLE}),
    RM.

cleanup(RM) ->
    catch ets:delete(?FILE_TABLE),
    catch ets:delete(?FOLDER_TABLE),
    RM.

%% -- Helpers --

make_file_registered_event() ->
    #{
        event_type => <<"file_registered_v1">>,
        file_id    => ?FILE_ID,
        name       => <<"notes.md">>,
        folder_id  => ?FOLDER_ID,
        file_type  => <<"markdown">>,
        plugin     => <<"hecate-app-scribe">>,
        icon       => <<"file-text">>,
        created_at => erlang:system_time(millisecond)
    }.

make_file_imported_event() ->
    #{
        event_type => <<"file_imported_v1">>,
        file_id    => <<"file-002">>,
        name       => <<"photo.jpg">>,
        folder_id  => ?FOLDER_ID,
        file_type  => <<"image">>,
        plugin     => <<"hecate-app-gallery">>,
        icon       => <<"image">>,
        blob_id    => <<"blob-abc123">>,
        size       => 204800,
        mime_type  => <<"image/jpeg">>,
        created_at => erlang:system_time(millisecond)
    }.

make_file_renamed_event() ->
    #{
        event_type => <<"file_renamed_v1">>,
        file_id    => ?FILE_ID,
        name       => <<"meeting-notes.md">>,
        renamed_at => erlang:system_time(millisecond)
    }.

make_file_moved_event() ->
    #{
        event_type => <<"file_moved_v1">>,
        file_id    => ?FILE_ID,
        folder_id  => <<"folder-archive">>,
        moved_at   => erlang:system_time(millisecond)
    }.

make_file_starred_event() ->
    #{
        event_type => <<"file_starred_v1">>,
        file_id    => ?FILE_ID,
        starred_at => erlang:system_time(millisecond)
    }.

make_file_unstarred_event() ->
    #{
        event_type   => <<"file_unstarred_v1">>,
        file_id      => ?FILE_ID,
        unstarred_at => erlang:system_time(millisecond)
    }.

make_file_archived_event() ->
    #{
        event_type  => <<"file_archived_v1">>,
        file_id     => ?FILE_ID,
        archived_at => erlang:system_time(millisecond)
    }.

wrap_event(Data) ->
    #{data => Data, event_type => maps:get(event_type, Data)}.

project(Data, State, RM) ->
    file_lifecycle_to_index:project(wrap_event(Data), #{}, State, RM).

%% ===================================================================
%% File Registered
%% ===================================================================

file_registered_projects_to_index_test() ->
    RM = setup(),
    try
        {ok, _S, _RM1} = project(make_file_registered_event(), #{}, RM),
        {ok, File} = project_briefcase_store:get_file(?FILE_ID),
        ?assertEqual(?FILE_ID, maps:get(file_id, File)),
        ?assertEqual(<<"notes.md">>, maps:get(name, File)),
        ?assertEqual(?FOLDER_ID, maps:get(folder_id, File)),
        ?assertEqual(<<"markdown">>, maps:get(file_type, File)),
        ?assertEqual(<<"hecate-app-scribe">>, maps:get(plugin, File)),
        ?assertEqual(<<"file-text">>, maps:get(icon, File)),
        ?assertEqual(undefined, maps:get(blob_id, File)),
        ?assertEqual(0, maps:get(size, File)),
        ?assertEqual(undefined, maps:get(mime_type, File)),
        ?assertEqual(false, maps:get(starred, File)),
        ?assertEqual(1, maps:get(status, File))
    after
        cleanup(RM)
    end.

%% ===================================================================
%% File Imported (with blob)
%% ===================================================================

file_imported_has_blob_test() ->
    RM = setup(),
    try
        {ok, _S, _RM1} = project(make_file_imported_event(), #{}, RM),
        {ok, File} = project_briefcase_store:get_file(<<"file-002">>),
        ?assertEqual(<<"file-002">>, maps:get(file_id, File)),
        ?assertEqual(<<"photo.jpg">>, maps:get(name, File)),
        ?assertEqual(<<"blob-abc123">>, maps:get(blob_id, File)),
        ?assertEqual(204800, maps:get(size, File)),
        ?assertEqual(<<"image/jpeg">>, maps:get(mime_type, File)),
        %% Status = INITIATED bor IMPORTED = 1 bor 32 = 33
        ?assertEqual(33, maps:get(status, File))
    after
        cleanup(RM)
    end.

%% ===================================================================
%% File Renamed
%% ===================================================================

file_renamed_updates_name_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_file_registered_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_file_renamed_event(), S1, RM1),
        {ok, File} = project_briefcase_store:get_file(?FILE_ID),
        ?assertEqual(<<"meeting-notes.md">>, maps:get(name, File)),
        %% Status should have RENAMED flag (bit 1 = 2)
        ?assertNotEqual(0, maps:get(status, File) band 2)
    after
        cleanup(RM)
    end.

file_renamed_before_register_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_file_renamed_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% File Moved
%% ===================================================================

file_moved_updates_folder_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_file_registered_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_file_moved_event(), S1, RM1),
        {ok, File} = project_briefcase_store:get_file(?FILE_ID),
        ?assertEqual(<<"folder-archive">>, maps:get(folder_id, File)),
        %% Status should have MOVED flag (bit 2 = 4)
        ?assertNotEqual(0, maps:get(status, File) band 4)
    after
        cleanup(RM)
    end.

file_moved_before_register_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_file_moved_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% File Starred / Unstarred
%% ===================================================================

file_starred_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_file_registered_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_file_starred_event(), S1, RM1),
        {ok, File} = project_briefcase_store:get_file(?FILE_ID),
        ?assertEqual(true, maps:get(starred, File)),
        %% Status should have STARRED flag (bit 4 = 16)
        ?assertNotEqual(0, maps:get(status, File) band 16)
    after
        cleanup(RM)
    end.

file_unstarred_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_file_registered_event(), #{}, RM),
        {ok, S2, RM2} = project(make_file_starred_event(), S1, RM1),
        {ok, _S3, _RM3} = project(make_file_unstarred_event(), S2, RM2),
        {ok, File} = project_briefcase_store:get_file(?FILE_ID),
        ?assertEqual(false, maps:get(starred, File))
    after
        cleanup(RM)
    end.

file_starred_before_register_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_file_starred_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% File Archived
%% ===================================================================

file_archived_removes_from_index_test() ->
    RM = setup(),
    try
        {ok, S1, RM1} = project(make_file_registered_event(), #{}, RM),
        {ok, _S2, _RM2} = project(make_file_archived_event(), S1, RM1),
        ?assertEqual({error, not_found}, project_briefcase_store:get_file(?FILE_ID))
    after
        cleanup(RM)
    end.

file_archived_before_register_skips_test() ->
    RM = setup(),
    try
        {skip, _S, _RM1} = project(make_file_archived_event(), #{}, RM)
    after
        cleanup(RM)
    end.

%% ===================================================================
%% Unknown Event
%% ===================================================================

unknown_event_skips_test() ->
    RM = setup(),
    try
        Event = #{event_type => <<"file_exploded_v1">>, data => #{}},
        {skip, _S, _RM1} = file_lifecycle_to_index:project(Event, #{}, #{}, RM)
    after
        cleanup(RM)
    end.
