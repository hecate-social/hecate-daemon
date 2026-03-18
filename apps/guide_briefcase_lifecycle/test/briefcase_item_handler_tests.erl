-module(briefcase_item_handler_tests).
-include_lib("eunit/include/eunit.hrl").

%% ===================================================================
%% Initiate Handler Tests
%% ===================================================================

initiate_valid_folder_test() ->
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<"Documents">>,
        kind => <<"folder">>
    },
    {ok, [Event]} = maybe_initiate_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"item-1">>, maps:get(item_id, Event)),
    ?assertEqual(<<"Documents">>, maps:get(name, Event)),
    ?assertEqual(<<"folder">>, maps:get(kind, Event)),
    ?assert(is_integer(maps:get(created_at, Event))).

initiate_valid_blob_test() ->
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-2">>,
        name => <<"photo.jpg">>,
        kind => <<"blob">>,
        plugin => <<"app_gallery">>,
        file_type => <<"image">>,
        mime_type => <<"image/jpeg">>,
        size => 2048,
        parent_id => <<"folder-1">>,
        icon => <<"image">>
    },
    {ok, [Event]} = maybe_initiate_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"blob">>, maps:get(kind, Event)),
    ?assertEqual(<<"app_gallery">>, maps:get(plugin, Event)),
    ?assertEqual(<<"image">>, maps:get(file_type, Event)),
    ?assertEqual(<<"image/jpeg">>, maps:get(mime_type, Event)),
    ?assertEqual(2048, maps:get(size, Event)),
    ?assertEqual(<<"folder-1">>, maps:get(parent_id, Event)),
    ?assertEqual(<<"image">>, maps:get(icon, Event)).

initiate_missing_name_test() ->
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-1">>,
        kind => <<"folder">>
    },
    ?assertEqual({error, name_required},
        maybe_initiate_briefcase_item:handle_from_map(Payload)).

initiate_empty_name_test() ->
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<>>,
        kind => <<"folder">>
    },
    ?assertEqual({error, name_required},
        maybe_initiate_briefcase_item:handle_from_map(Payload)).

initiate_missing_item_id_test() ->
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        name => <<"Folder">>,
        kind => <<"folder">>
    },
    ?assertEqual({error, item_id_required},
        maybe_initiate_briefcase_item:handle_from_map(Payload)).

initiate_invalid_kind_test() ->
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<"Test">>,
        kind => <<"invalid">>
    },
    ?assertEqual({error, invalid_kind},
        maybe_initiate_briefcase_item:handle_from_map(Payload)).

%% ===================================================================
%% Rename Handler Tests
%% ===================================================================

rename_valid_test() ->
    Payload = #{
        command_type => <<"rename_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<"New Name">>
    },
    {ok, [Event]} = maybe_rename_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_renamed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"item-1">>, maps:get(item_id, Event)),
    ?assertEqual(<<"New Name">>, maps:get(name, Event)),
    ?assert(is_integer(maps:get(renamed_at, Event))).

rename_empty_name_test() ->
    Payload = #{
        command_type => <<"rename_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<>>
    },
    ?assertEqual({error, name_required},
        maybe_rename_briefcase_item:handle_from_map(Payload)).

rename_missing_name_test() ->
    Payload = #{
        command_type => <<"rename_briefcase_item">>,
        item_id => <<"item-1">>
    },
    ?assertEqual({error, name_required},
        maybe_rename_briefcase_item:handle_from_map(Payload)).

%% ===================================================================
%% Move Handler Tests
%% ===================================================================

move_valid_test() ->
    Payload = #{
        command_type => <<"move_briefcase_item">>,
        item_id => <<"item-1">>,
        parent_id => <<"folder-2">>
    },
    {ok, [Event]} = maybe_move_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_moved_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"folder-2">>, maps:get(parent_id, Event)),
    ?assert(is_integer(maps:get(moved_at, Event))).

move_missing_item_id_test() ->
    Payload = #{
        command_type => <<"move_briefcase_item">>,
        parent_id => <<"folder-2">>
    },
    ?assertEqual({error, item_id_required},
        maybe_move_briefcase_item:handle_from_map(Payload)).

%% ===================================================================
%% Star / Unstar Handler Tests
%% ===================================================================

star_valid_test() ->
    Payload = #{
        command_type => <<"star_briefcase_item">>,
        item_id => <<"item-1">>
    },
    {ok, [Event]} = maybe_star_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_starred_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(starred_at, Event))).

star_missing_item_id_test() ->
    Payload = #{command_type => <<"star_briefcase_item">>},
    ?assertEqual({error, item_id_required},
        maybe_star_briefcase_item:handle_from_map(Payload)).

unstar_valid_test() ->
    Payload = #{
        command_type => <<"unstar_briefcase_item">>,
        item_id => <<"item-1">>
    },
    {ok, [Event]} = maybe_unstar_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_unstarred_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(unstarred_at, Event))).

unstar_missing_item_id_test() ->
    Payload = #{command_type => <<"unstar_briefcase_item">>},
    ?assertEqual({error, item_id_required},
        maybe_unstar_briefcase_item:handle_from_map(Payload)).

%% ===================================================================
%% Archive Handler Tests
%% ===================================================================

archive_valid_test() ->
    Payload = #{
        command_type => <<"archive_briefcase_item">>,
        item_id => <<"item-1">>
    },
    {ok, [Event]} = maybe_archive_briefcase_item:handle_from_map(Payload),
    ?assertEqual(<<"briefcase_item_archived_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(archived_at, Event))).

archive_missing_item_id_test() ->
    Payload = #{command_type => <<"archive_briefcase_item">>},
    ?assertEqual({error, item_id_required},
        maybe_archive_briefcase_item:handle_from_map(Payload)).
