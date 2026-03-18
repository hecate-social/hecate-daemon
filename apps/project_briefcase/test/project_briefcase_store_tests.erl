%%% @doc Tests for project_briefcase_store query functions.
%%%
%%% Creates ETS tables directly (bypassing gen_server) to test
%%% the query API: list_folders, get_folder, list_files, get_file,
%%% count_files_in_folder, and filter logic.
%%% @end
-module(project_briefcase_store_tests).

-include_lib("eunit/include/eunit.hrl").

-define(FOLDER_TABLE, briefcase_folder_tree).
-define(FILE_TABLE, briefcase_file_index).

%% -- Setup / Teardown --

setup() ->
    ets:new(?FOLDER_TABLE, [set, public, named_table, {read_concurrency, true}]),
    ets:new(?FILE_TABLE, [set, public, named_table, {read_concurrency, true}]),
    ok.

cleanup(_) ->
    catch ets:delete(?FOLDER_TABLE),
    catch ets:delete(?FILE_TABLE),
    ok.

%% -- Helpers --

make_folder(Id, Name) ->
    make_folder(Id, Name, undefined).

make_folder(Id, Name, ParentId) ->
    #{
        folder_id  => Id,
        name       => Name,
        parent_id  => ParentId,
        icon       => <<"folder">>,
        status     => 1,
        created_at => erlang:system_time(millisecond),
        updated_at => erlang:system_time(millisecond)
    }.

make_file(Id, Name, FolderId) ->
    make_file(Id, Name, FolderId, #{}).

make_file(Id, Name, FolderId, Overrides) ->
    Base = #{
        file_id    => Id,
        name       => Name,
        folder_id  => FolderId,
        file_type  => <<"document">>,
        plugin     => <<"hecate-app-scribe">>,
        icon       => <<"file-text">>,
        blob_id    => undefined,
        size       => 0,
        mime_type  => undefined,
        starred    => false,
        status     => 1,
        created_at => erlang:system_time(millisecond),
        updated_at => erlang:system_time(millisecond)
    },
    maps:merge(Base, Overrides).

%% ===================================================================
%% Folder Tests
%% ===================================================================

put_and_get_folder_test() ->
    setup(),
    try
        Folder = make_folder(<<"f-1">>, <<"Documents">>),
        ok = project_briefcase_store:put_folder(<<"f-1">>, Folder),
        ?assertEqual({ok, Folder}, project_briefcase_store:get_folder(<<"f-1">>))
    after
        cleanup(ok)
    end.

get_missing_folder_test() ->
    setup(),
    try
        ?assertEqual({error, not_found}, project_briefcase_store:get_folder(<<"nonexistent">>))
    after
        cleanup(ok)
    end.

list_folders_test() ->
    setup(),
    try
        F1 = make_folder(<<"f-1">>, <<"Documents">>),
        F2 = make_folder(<<"f-2">>, <<"Photos">>),
        F3 = make_folder(<<"f-3">>, <<"Music">>),
        ok = project_briefcase_store:put_folder(<<"f-1">>, F1),
        ok = project_briefcase_store:put_folder(<<"f-2">>, F2),
        ok = project_briefcase_store:put_folder(<<"f-3">>, F3),
        Folders = project_briefcase_store:list_folders(),
        ?assertEqual(3, length(Folders)),
        Ids = lists:sort([maps:get(folder_id, F) || F <- Folders]),
        ?assertEqual([<<"f-1">>, <<"f-2">>, <<"f-3">>], Ids)
    after
        cleanup(ok)
    end.

delete_folder_test() ->
    setup(),
    try
        Folder = make_folder(<<"f-1">>, <<"Documents">>),
        ok = project_briefcase_store:put_folder(<<"f-1">>, Folder),
        ok = project_briefcase_store:delete_folder(<<"f-1">>),
        ?assertEqual({error, not_found}, project_briefcase_store:get_folder(<<"f-1">>))
    after
        cleanup(ok)
    end.

%% ===================================================================
%% File Tests
%% ===================================================================

put_and_get_file_test() ->
    setup(),
    try
        File = make_file(<<"file-1">>, <<"notes.md">>, <<"f-1">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, File),
        ?assertEqual({ok, File}, project_briefcase_store:get_file(<<"file-1">>))
    after
        cleanup(ok)
    end.

get_missing_file_test() ->
    setup(),
    try
        ?assertEqual({error, not_found}, project_briefcase_store:get_file(<<"nonexistent">>))
    after
        cleanup(ok)
    end.

delete_file_test() ->
    setup(),
    try
        File = make_file(<<"file-1">>, <<"notes.md">>, <<"f-1">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, File),
        ok = project_briefcase_store:delete_file(<<"file-1">>),
        ?assertEqual({error, not_found}, project_briefcase_store:get_file(<<"file-1">>))
    after
        cleanup(ok)
    end.

%% ===================================================================
%% list_files Filter Tests
%% ===================================================================

list_files_filter_by_folder_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, <<"folder-a">>),
        F2 = make_file(<<"file-2">>, <<"b.md">>, <<"folder-a">>),
        F3 = make_file(<<"file-3">>, <<"c.md">>, <<"folder-b">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ok = project_briefcase_store:put_file(<<"file-3">>, F3),
        Result = project_briefcase_store:list_files(#{folder_id => <<"folder-a">>}),
        ?assertEqual(2, length(Result)),
        Ids = lists:sort([maps:get(file_id, F) || F <- Result]),
        ?assertEqual([<<"file-1">>, <<"file-2">>], Ids)
    after
        cleanup(ok)
    end.

list_files_folder_all_returns_everything_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, <<"folder-a">>),
        F2 = make_file(<<"file-2">>, <<"b.md">>, <<"folder-b">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        Result = project_briefcase_store:list_files(#{folder_id => <<"all">>}),
        ?assertEqual(2, length(Result))
    after
        cleanup(ok)
    end.

list_files_filter_starred_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, <<"f-1">>, #{starred => true}),
        F2 = make_file(<<"file-2">>, <<"b.md">>, <<"f-1">>, #{starred => false}),
        F3 = make_file(<<"file-3">>, <<"c.md">>, <<"f-1">>, #{starred => true}),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ok = project_briefcase_store:put_file(<<"file-3">>, F3),
        Result = project_briefcase_store:list_files(#{starred => true}),
        ?assertEqual(2, length(Result)),
        Ids = lists:sort([maps:get(file_id, F) || F <- Result]),
        ?assertEqual([<<"file-1">>, <<"file-3">>], Ids)
    after
        cleanup(ok)
    end.

list_files_search_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"meeting-notes.md">>, <<"f-1">>),
        F2 = make_file(<<"file-2">>, <<"shopping-list.md">>, <<"f-1">>),
        F3 = make_file(<<"file-3">>, <<"Meeting-agenda.md">>, <<"f-1">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ok = project_briefcase_store:put_file(<<"file-3">>, F3),
        %% Case-insensitive search for "meeting"
        Result = project_briefcase_store:list_files(#{search => <<"meeting">>}),
        ?assertEqual(2, length(Result)),
        Ids = lists:sort([maps:get(file_id, F) || F <- Result]),
        ?assertEqual([<<"file-1">>, <<"file-3">>], Ids)
    after
        cleanup(ok)
    end.

list_files_filter_file_type_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, <<"f-1">>, #{file_type => <<"markdown">>}),
        F2 = make_file(<<"file-2">>, <<"b.jpg">>, <<"f-1">>, #{file_type => <<"image">>}),
        F3 = make_file(<<"file-3">>, <<"c.md">>, <<"f-1">>, #{file_type => <<"markdown">>}),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ok = project_briefcase_store:put_file(<<"file-3">>, F3),
        Result = project_briefcase_store:list_files(#{file_type => <<"markdown">>}),
        ?assertEqual(2, length(Result))
    after
        cleanup(ok)
    end.

list_files_excludes_archived_test() ->
    setup(),
    try
        %% Status with ARCHIVED bit (8) set
        F1 = make_file(<<"file-1">>, <<"alive.md">>, <<"f-1">>),
        F2 = make_file(<<"file-2">>, <<"dead.md">>, <<"f-1">>, #{status => 1 bor 8}),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        Result = project_briefcase_store:list_files(#{}),
        ?assertEqual(1, length(Result)),
        ?assertEqual(<<"file-1">>, maps:get(file_id, hd(Result)))
    after
        cleanup(ok)
    end.

list_files_combined_filters_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"meeting.md">>, <<"f-1">>, #{starred => true}),
        F2 = make_file(<<"file-2">>, <<"meeting.md">>, <<"f-2">>, #{starred => true}),
        F3 = make_file(<<"file-3">>, <<"other.md">>, <<"f-1">>, #{starred => true}),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ok = project_briefcase_store:put_file(<<"file-3">>, F3),
        %% Filter: folder f-1 + starred + search "meeting"
        Result = project_briefcase_store:list_files(#{
            folder_id => <<"f-1">>,
            starred => true,
            search => <<"meeting">>
        }),
        ?assertEqual(1, length(Result)),
        ?assertEqual(<<"file-1">>, maps:get(file_id, hd(Result)))
    after
        cleanup(ok)
    end.

%% ===================================================================
%% count_files_in_folder
%% ===================================================================

count_files_in_folder_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, <<"f-1">>),
        F2 = make_file(<<"file-2">>, <<"b.md">>, <<"f-1">>),
        F3 = make_file(<<"file-3">>, <<"c.md">>, <<"f-2">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ok = project_briefcase_store:put_file(<<"file-3">>, F3),
        ?assertEqual(2, project_briefcase_store:count_files_in_folder(<<"f-1">>)),
        ?assertEqual(1, project_briefcase_store:count_files_in_folder(<<"f-2">>)),
        ?assertEqual(0, project_briefcase_store:count_files_in_folder(<<"f-nonexistent">>))
    after
        cleanup(ok)
    end.

count_files_excludes_archived_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, <<"f-1">>),
        F2 = make_file(<<"file-2">>, <<"b.md">>, <<"f-1">>, #{status => 1 bor 8}),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ?assertEqual(1, project_briefcase_store:count_files_in_folder(<<"f-1">>))
    after
        cleanup(ok)
    end.

count_files_in_root_folder_test() ->
    setup(),
    try
        F1 = make_file(<<"file-1">>, <<"a.md">>, undefined),
        F2 = make_file(<<"file-2">>, <<"b.md">>, <<"f-1">>),
        ok = project_briefcase_store:put_file(<<"file-1">>, F1),
        ok = project_briefcase_store:put_file(<<"file-2">>, F2),
        ?assertEqual(1, project_briefcase_store:count_files_in_folder(undefined))
    after
        cleanup(ok)
    end.
