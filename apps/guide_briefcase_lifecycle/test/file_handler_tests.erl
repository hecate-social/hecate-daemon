-module(file_handler_tests).
-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% maybe_register_file tests
%% ===================================================================

register_valid_test() ->
    {ok, Cmd} = register_file_v1:new(#{
        file_id   => <<"file-001">>,
        name      => <<"notes.txt">>,
        file_type => <<"text">>,
        plugin    => <<"editor">>,
        folder_id => <<"folder-1">>,
        icon      => <<"\xF0\x9F\x93\x84">>
    }),
    {ok, [Event]} = maybe_register_file:handle(Cmd),
    Map = file_registered_v1:to_map(Event),
    ?assertEqual(<<"file_registered_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"file-001">>, maps:get(file_id, Map)),
    ?assertEqual(<<"notes.txt">>, maps:get(name, Map)),
    ?assertEqual(<<"text">>, maps:get(file_type, Map)),
    ?assertEqual(<<"editor">>, maps:get(plugin, Map)),
    ?assertEqual(<<"folder-1">>, maps:get(folder_id, Map)),
    ?assert(is_integer(maps:get(created_at, Map))).

register_minimal_test() ->
    {ok, Cmd} = register_file_v1:new(#{
        file_id   => <<"file-002">>,
        name      => <<"data.bin">>,
        file_type => <<"binary">>
    }),
    {ok, [Event]} = maybe_register_file:handle(Cmd),
    Map = file_registered_v1:to_map(Event),
    ?assertEqual(<<"file-002">>, maps:get(file_id, Map)),
    %% Optional fields omitted by maybe_put
    ?assertEqual(error, maps:find(plugin, Map)),
    ?assertEqual(error, maps:find(folder_id, Map)),
    ?assertEqual(error, maps:find(icon, Map)).

register_empty_name_test() ->
    {ok, Cmd} = register_file_v1:new(#{
        file_id   => <<"file-003">>,
        name      => <<>>,
        file_type => <<"text">>
    }),
    ?assertEqual({error, invalid_name}, maybe_register_file:handle(Cmd)).

register_empty_file_type_test() ->
    {ok, Cmd} = register_file_v1:new(#{
        file_id   => <<"file-004">>,
        name      => <<"test.txt">>,
        file_type => <<>>
    }),
    ?assertEqual({error, invalid_file_type}, maybe_register_file:handle(Cmd)).

register_empty_file_id_test() ->
    {ok, Cmd} = register_file_v1:new(#{
        file_id   => <<>>,
        name      => <<"test.txt">>,
        file_type => <<"text">>
    }),
    ?assertEqual({error, invalid_file_id}, maybe_register_file:handle(Cmd)).

register_missing_required_test() ->
    ?assertEqual({error, missing_required_fields},
                 register_file_v1:new(#{file_id => <<"x">>, name => <<"y">>})).

%% ===================================================================
%% maybe_import_file tests
%% ===================================================================

import_valid_test() ->
    {ok, Cmd} = import_file_v1:new(#{
        file_id   => <<"file-010">>,
        name      => <<"photo.jpg">>,
        file_type => <<"image">>,
        blob_id   => <<"blob-abc">>,
        size      => 102400,
        mime_type => <<"image/jpeg">>,
        plugin    => <<"gallery">>,
        folder_id => <<"folder-1">>
    }),
    {ok, [Event]} = maybe_import_file:handle(Cmd),
    Map = file_imported_v1:to_map(Event),
    ?assertEqual(<<"file_imported_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"file-010">>, maps:get(file_id, Map)),
    ?assertEqual(<<"photo.jpg">>, maps:get(name, Map)),
    ?assertEqual(<<"blob-abc">>, maps:get(blob_id, Map)),
    ?assertEqual(102400, maps:get(size, Map)),
    ?assertEqual(<<"image/jpeg">>, maps:get(mime_type, Map)).

import_minimal_test() ->
    {ok, Cmd} = import_file_v1:new(#{
        file_id   => <<"file-011">>,
        name      => <<"doc.pdf">>,
        file_type => <<"document">>,
        blob_id   => <<"blob-def">>,
        size      => 0
    }),
    {ok, [Event]} = maybe_import_file:handle(Cmd),
    Map = file_imported_v1:to_map(Event),
    ?assertEqual(<<"file-011">>, maps:get(file_id, Map)),
    ?assertEqual(0, maps:get(size, Map)),
    %% Optional fields omitted
    ?assertEqual(error, maps:find(mime_type, Map)),
    ?assertEqual(error, maps:find(plugin, Map)),
    ?assertEqual(error, maps:find(folder_id, Map)).

import_empty_blob_id_test() ->
    {ok, Cmd} = import_file_v1:new(#{
        file_id   => <<"file-012">>,
        name      => <<"test.txt">>,
        file_type => <<"text">>,
        blob_id   => <<>>,
        size      => 100
    }),
    ?assertEqual({error, invalid_blob_id}, maybe_import_file:handle(Cmd)).

import_empty_name_test() ->
    {ok, Cmd} = import_file_v1:new(#{
        file_id   => <<"file-013">>,
        name      => <<>>,
        file_type => <<"text">>,
        blob_id   => <<"blob-x">>,
        size      => 100
    }),
    ?assertEqual({error, invalid_name}, maybe_import_file:handle(Cmd)).

import_empty_file_type_test() ->
    {ok, Cmd} = import_file_v1:new(#{
        file_id   => <<"file-014">>,
        name      => <<"test.txt">>,
        file_type => <<>>,
        blob_id   => <<"blob-x">>,
        size      => 100
    }),
    ?assertEqual({error, invalid_file_type}, maybe_import_file:handle(Cmd)).

import_negative_size_test() ->
    {ok, Cmd} = import_file_v1:new(#{
        file_id   => <<"file-015">>,
        name      => <<"test.txt">>,
        file_type => <<"text">>,
        blob_id   => <<"blob-x">>,
        size      => -1
    }),
    ?assertEqual({error, invalid_size}, maybe_import_file:handle(Cmd)).

import_missing_required_test() ->
    ?assertEqual({error, missing_required_fields},
                 import_file_v1:new(#{file_id => <<"x">>, name => <<"y">>,
                                      file_type => <<"z">>})).

%% ===================================================================
%% maybe_rename_file tests
%% ===================================================================

rename_file_valid_test() ->
    {ok, Cmd} = rename_file_v1:new(#{
        file_id => <<"file-001">>,
        name    => <<"renamed.txt">>
    }),
    {ok, [Event]} = maybe_rename_file:handle(Cmd),
    Map = file_renamed_v1:to_map(Event),
    ?assertEqual(<<"file_renamed_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"renamed.txt">>, maps:get(name, Map)).

rename_file_empty_name_test() ->
    {ok, Cmd} = rename_file_v1:new(#{
        file_id => <<"file-001">>,
        name    => <<>>
    }),
    ?assertEqual({error, invalid_name}, maybe_rename_file:handle(Cmd)).

%% ===================================================================
%% maybe_move_file tests
%% ===================================================================

move_file_valid_test() ->
    {ok, Cmd} = move_file_v1:new(#{
        file_id   => <<"file-001">>,
        folder_id => <<"folder-2">>
    }),
    {ok, [Event]} = maybe_move_file:handle(Cmd),
    Map = file_moved_v1:to_map(Event),
    ?assertEqual(<<"file_moved_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"folder-2">>, maps:get(folder_id, Map)).

move_file_empty_file_id_test() ->
    {ok, Cmd} = move_file_v1:new(#{
        file_id   => <<>>,
        folder_id => <<"folder-2">>
    }),
    ?assertEqual({error, invalid_file_id}, maybe_move_file:handle(Cmd)).

%% ===================================================================
%% maybe_star_file / maybe_unstar_file tests
%% ===================================================================

star_file_valid_test() ->
    {ok, Cmd} = star_file_v1:new(#{file_id => <<"file-001">>}),
    {ok, [Event]} = maybe_star_file:handle(Cmd),
    Map = file_starred_v1:to_map(Event),
    ?assertEqual(<<"file_starred_v1">>, maps:get(event_type, Map)).

star_file_empty_id_test() ->
    {ok, Cmd} = star_file_v1:new(#{file_id => <<>>}),
    ?assertEqual({error, invalid_file_id}, maybe_star_file:handle(Cmd)).

unstar_file_valid_test() ->
    {ok, Cmd} = unstar_file_v1:new(#{file_id => <<"file-001">>}),
    {ok, [Event]} = maybe_unstar_file:handle(Cmd),
    Map = file_unstarred_v1:to_map(Event),
    ?assertEqual(<<"file_unstarred_v1">>, maps:get(event_type, Map)).

unstar_file_empty_id_test() ->
    {ok, Cmd} = unstar_file_v1:new(#{file_id => <<>>}),
    ?assertEqual({error, invalid_file_id}, maybe_unstar_file:handle(Cmd)).

%% ===================================================================
%% maybe_archive_file tests
%% ===================================================================

archive_file_valid_test() ->
    {ok, Cmd} = archive_file_v1:new(#{file_id => <<"file-001">>}),
    {ok, [Event]} = maybe_archive_file:handle(Cmd),
    Map = file_archived_v1:to_map(Event),
    ?assertEqual(<<"file_archived_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"file-001">>, maps:get(file_id, Map)).

archive_file_empty_id_test() ->
    {ok, Cmd} = archive_file_v1:new(#{file_id => <<>>}),
    ?assertEqual({error, invalid_file_id}, maybe_archive_file:handle(Cmd)).
