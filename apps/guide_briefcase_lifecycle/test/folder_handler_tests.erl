-module(folder_handler_tests).
-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% maybe_create_folder tests
%% ===================================================================

create_valid_test() ->
    {ok, Cmd} = create_folder_v1:new(#{
        folder_id => <<"folder-1">>,
        name      => <<"Work">>,
        parent_id => <<"root">>,
        icon      => <<"\xF0\x9F\x93\x81">>
    }),
    {ok, [Event]} = maybe_create_folder:handle(Cmd),
    Map = folder_initiated_v1:to_map(Event),
    ?assertEqual(<<"folder_initiated_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"folder-1">>, maps:get(folder_id, Map)),
    ?assertEqual(<<"Work">>, maps:get(name, Map)),
    ?assertEqual(<<"root">>, maps:get(parent_id, Map)),
    ?assert(is_integer(maps:get(created_at, Map))).

create_no_parent_test() ->
    {ok, Cmd} = create_folder_v1:new(#{
        folder_id => <<"folder-2">>,
        name      => <<"Root Folder">>
    }),
    {ok, [Event]} = maybe_create_folder:handle(Cmd),
    Map = folder_initiated_v1:to_map(Event),
    ?assertEqual(<<"folder-2">>, maps:get(folder_id, Map)),
    %% parent_id omitted by maybe_put when undefined
    ?assertEqual(error, maps:find(parent_id, Map)).

create_empty_name_test() ->
    {ok, Cmd} = create_folder_v1:new(#{
        folder_id => <<"folder-3">>,
        name      => <<>>
    }),
    ?assertEqual({error, invalid_name}, maybe_create_folder:handle(Cmd)).

create_empty_folder_id_test() ->
    {ok, Cmd} = create_folder_v1:new(#{
        folder_id => <<>>,
        name      => <<"Test">>
    }),
    ?assertEqual({error, invalid_folder_id}, maybe_create_folder:handle(Cmd)).

%% ===================================================================
%% maybe_rename_folder tests
%% ===================================================================

rename_valid_test() ->
    {ok, Cmd} = rename_folder_v1:new(#{
        folder_id => <<"folder-1">>,
        name      => <<"Personal">>
    }),
    {ok, [Event]} = maybe_rename_folder:handle(Cmd),
    Map = folder_renamed_v1:to_map(Event),
    ?assertEqual(<<"folder_renamed_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"folder-1">>, maps:get(folder_id, Map)),
    ?assertEqual(<<"Personal">>, maps:get(name, Map)),
    ?assert(is_integer(maps:get(renamed_at, Map))).

rename_empty_name_test() ->
    {ok, Cmd} = rename_folder_v1:new(#{
        folder_id => <<"folder-1">>,
        name      => <<>>
    }),
    ?assertEqual({error, invalid_name}, maybe_rename_folder:handle(Cmd)).

rename_empty_folder_id_test() ->
    {ok, Cmd} = rename_folder_v1:new(#{
        folder_id => <<>>,
        name      => <<"Test">>
    }),
    ?assertEqual({error, invalid_folder_id}, maybe_rename_folder:handle(Cmd)).

%% ===================================================================
%% maybe_move_folder tests
%% ===================================================================

move_valid_test() ->
    {ok, Cmd} = move_folder_v1:new(#{
        folder_id => <<"folder-1">>,
        parent_id => <<"new-parent">>
    }),
    {ok, [Event]} = maybe_move_folder:handle(Cmd),
    Map = folder_moved_v1:to_map(Event),
    ?assertEqual(<<"folder_moved_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"new-parent">>, maps:get(parent_id, Map)).

move_to_root_test() ->
    {ok, Cmd} = move_folder_v1:new(#{
        folder_id => <<"folder-1">>
    }),
    {ok, [Event]} = maybe_move_folder:handle(Cmd),
    Map = folder_moved_v1:to_map(Event),
    ?assertEqual(<<"folder_moved_v1">>, maps:get(event_type, Map)),
    %% parent_id omitted when undefined
    ?assertEqual(error, maps:find(parent_id, Map)).

move_empty_folder_id_test() ->
    {ok, Cmd} = move_folder_v1:new(#{
        folder_id => <<>>
    }),
    ?assertEqual({error, invalid_folder_id}, maybe_move_folder:handle(Cmd)).

%% ===================================================================
%% maybe_archive_folder tests
%% ===================================================================

archive_valid_test() ->
    {ok, Cmd} = archive_folder_v1:new(#{
        folder_id => <<"folder-1">>
    }),
    {ok, [Event]} = maybe_archive_folder:handle(Cmd),
    Map = folder_archived_v1:to_map(Event),
    ?assertEqual(<<"folder_archived_v1">>, maps:get(event_type, Map)),
    ?assertEqual(<<"folder-1">>, maps:get(folder_id, Map)),
    ?assert(is_integer(maps:get(archived_at, Map))).

archive_empty_folder_id_test() ->
    {ok, Cmd} = archive_folder_v1:new(#{
        folder_id => <<>>
    }),
    ?assertEqual({error, invalid_folder_id}, maybe_archive_folder:handle(Cmd)).
