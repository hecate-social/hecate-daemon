-module(file_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").

-include("file_status.hrl").
-include("file_state.hrl").

%% ===================================================================
%% Execute tests — happy path (register birth)
%% ===================================================================

register_file_test() ->
    State = file_state:new(<<"file-001">>),
    Payload = #{
        command_type => <<"register_file">>,
        file_id    => <<"file-001">>,
        name       => <<"notes.txt">>,
        file_type  => <<"text">>,
        plugin     => <<"editor">>,
        folder_id  => <<"folder-1">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_registered_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"file-001">>, maps:get(file_id, Event)),
    ?assertEqual(<<"notes.txt">>, maps:get(name, Event)),
    ?assertEqual(<<"text">>, maps:get(file_type, Event)),
    ?assertEqual(<<"editor">>, maps:get(plugin, Event)),
    ?assert(is_integer(maps:get(created_at, Event))).

import_file_test() ->
    State = file_state:new(<<"file-002">>),
    Payload = #{
        command_type => <<"import_file">>,
        file_id    => <<"file-002">>,
        name       => <<"photo.jpg">>,
        file_type  => <<"image">>,
        blob_id    => <<"blob-abc">>,
        size       => 102400,
        mime_type  => <<"image/jpeg">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_imported_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"file-002">>, maps:get(file_id, Event)),
    ?assertEqual(<<"photo.jpg">>, maps:get(name, Event)),
    ?assertEqual(<<"blob-abc">>, maps:get(blob_id, Event)),
    ?assertEqual(102400, maps:get(size, Event)),
    ?assertEqual(<<"image/jpeg">>, maps:get(mime_type, Event)).

%% ===================================================================
%% Execute tests — happy path (post-init commands)
%% ===================================================================

rename_file_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"rename_file">>,
        file_id => <<"file-001">>,
        name => <<"renamed.txt">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_renamed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"renamed.txt">>, maps:get(name, Event)).

move_file_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"move_file">>,
        file_id => <<"file-001">>,
        folder_id => <<"folder-2">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_moved_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"folder-2">>, maps:get(folder_id, Event)).

star_file_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"star_file">>,
        file_id => <<"file-001">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_starred_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(starred_at, Event))).

unstar_file_test() ->
    State = starred_state(),
    Payload = #{
        command_type => <<"unstar_file">>,
        file_id => <<"file-001">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_unstarred_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(unstarred_at, Event))).

archive_file_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"archive_file">>,
        file_id => <<"file-001">>
    },
    {ok, [Event]} = file_aggregate:execute(State, Payload),
    ?assertEqual(<<"file_archived_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(archived_at, Event))).

%% ===================================================================
%% Execute tests — errors
%% ===================================================================

register_already_initiated_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"register_file">>,
        file_id => <<"file-001">>,
        name => <<"dup.txt">>,
        file_type => <<"text">>
    },
    ?assertEqual({error, file_already_initiated},
                 file_aggregate:execute(State, Payload)).

import_already_initiated_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"import_file">>,
        file_id => <<"file-001">>,
        name => <<"dup.jpg">>,
        file_type => <<"image">>,
        blob_id => <<"blob-x">>,
        size => 0
    },
    ?assertEqual({error, file_already_initiated},
                 file_aggregate:execute(State, Payload)).

star_already_starred_test() ->
    State = starred_state(),
    Payload = #{
        command_type => <<"star_file">>,
        file_id => <<"file-001">>
    },
    ?assertEqual({error, file_already_starred},
                 file_aggregate:execute(State, Payload)).

unstar_not_starred_test() ->
    State = registered_state(),
    Payload = #{
        command_type => <<"unstar_file">>,
        file_id => <<"file-001">>
    },
    ?assertEqual({error, file_not_starred},
                 file_aggregate:execute(State, Payload)).

rename_archived_test() ->
    State = archived_state(),
    Payload = #{
        command_type => <<"rename_file">>,
        file_id => <<"file-001">>,
        name => <<"nope.txt">>
    },
    ?assertEqual({error, file_archived},
                 file_aggregate:execute(State, Payload)).

star_archived_test() ->
    State = archived_state(),
    Payload = #{
        command_type => <<"star_file">>,
        file_id => <<"file-001">>
    },
    ?assertEqual({error, file_archived},
                 file_aggregate:execute(State, Payload)).

archive_already_archived_test() ->
    State = archived_state(),
    Payload = #{
        command_type => <<"archive_file">>,
        file_id => <<"file-001">>
    },
    ?assertEqual({error, file_archived},
                 file_aggregate:execute(State, Payload)).

rename_not_initiated_test() ->
    State = file_state:new(<<"file-001">>),
    Payload = #{
        command_type => <<"rename_file">>,
        file_id => <<"file-001">>,
        name => <<"nope.txt">>
    },
    ?assertEqual({error, file_not_initiated},
                 file_aggregate:execute(State, Payload)).

unknown_command_fresh_test() ->
    State = file_state:new(<<"file-001">>),
    ?assertEqual({error, file_not_initiated},
                 file_aggregate:execute(State, #{command_type => <<"bogus">>})).

unknown_command_initiated_test() ->
    State = registered_state(),
    ?assertEqual({error, unknown_command},
                 file_aggregate:execute(State, #{command_type => <<"bogus">>})).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_registered_test() ->
    S0 = file_state:new(<<"file-001">>),
    Event = #{
        event_type => <<"file_registered_v1">>,
        file_id    => <<"file-001">>,
        name       => <<"notes.txt">>,
        file_type  => <<"text">>,
        plugin     => <<"editor">>,
        folder_id  => <<"folder-1">>,
        icon       => <<"\xF0\x9F\x93\x84">>,
        created_at => 1000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(<<"file-001">>, S1#file_state.file_id),
    ?assertEqual(<<"notes.txt">>, S1#file_state.name),
    ?assertEqual(<<"text">>, S1#file_state.file_type),
    ?assertEqual(<<"editor">>, S1#file_state.plugin),
    ?assertEqual(<<"folder-1">>, S1#file_state.folder_id),
    ?assertEqual(undefined, S1#file_state.blob_id),
    ?assertEqual(0, S1#file_state.size),
    ?assertEqual(false, S1#file_state.starred),
    ?assertEqual(?FILE_INITIATED, S1#file_state.status),
    ?assertEqual(1000, S1#file_state.created_at).

apply_imported_test() ->
    S0 = file_state:new(<<"file-002">>),
    Event = #{
        event_type => <<"file_imported_v1">>,
        file_id    => <<"file-002">>,
        name       => <<"photo.jpg">>,
        file_type  => <<"image">>,
        blob_id    => <<"blob-abc">>,
        size       => 102400,
        mime_type  => <<"image/jpeg">>,
        created_at => 2000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(<<"file-002">>, S1#file_state.file_id),
    ?assertEqual(<<"photo.jpg">>, S1#file_state.name),
    ?assertEqual(<<"blob-abc">>, S1#file_state.blob_id),
    ?assertEqual(102400, S1#file_state.size),
    ?assertEqual(<<"image/jpeg">>, S1#file_state.mime_type),
    %% FILE_INITIATED | FILE_IMPORTED
    ?assertNotEqual(0, S1#file_state.status band ?FILE_INITIATED),
    ?assertNotEqual(0, S1#file_state.status band ?FILE_IMPORTED),
    ?assertEqual(false, S1#file_state.starred).

apply_renamed_test() ->
    S0 = registered_state(),
    Event = #{
        event_type => <<"file_renamed_v1">>,
        file_id    => <<"file-001">>,
        name       => <<"renamed.txt">>,
        renamed_at => 3000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(<<"renamed.txt">>, S1#file_state.name),
    ?assertNotEqual(0, S1#file_state.status band ?FILE_RENAMED),
    ?assertEqual(3000, S1#file_state.updated_at).

apply_moved_test() ->
    S0 = registered_state(),
    Event = #{
        event_type => <<"file_moved_v1">>,
        file_id    => <<"file-001">>,
        folder_id  => <<"folder-2">>,
        moved_at   => 4000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(<<"folder-2">>, S1#file_state.folder_id),
    ?assertNotEqual(0, S1#file_state.status band ?FILE_MOVED),
    ?assertEqual(4000, S1#file_state.updated_at).

apply_starred_test() ->
    S0 = registered_state(),
    Event = #{
        event_type => <<"file_starred_v1">>,
        file_id    => <<"file-001">>,
        starred_at => 5000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(true, S1#file_state.starred),
    ?assertNotEqual(0, S1#file_state.status band ?FILE_STARRED),
    ?assertEqual(5000, S1#file_state.updated_at).

apply_unstarred_test() ->
    S0 = starred_state(),
    Event = #{
        event_type   => <<"file_unstarred_v1">>,
        file_id      => <<"file-001">>,
        unstarred_at => 6000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(false, S1#file_state.starred),
    %% STARRED bit should be cleared
    ?assertEqual(0, S1#file_state.status band ?FILE_STARRED),
    ?assertEqual(6000, S1#file_state.updated_at).

apply_archived_test() ->
    S0 = registered_state(),
    Event = #{
        event_type  => <<"file_archived_v1">>,
        file_id     => <<"file-001">>,
        archived_at => 7000
    },
    S1 = file_aggregate:apply(S0, Event),
    ?assertNotEqual(0, S1#file_state.status band ?FILE_ARCHIVED),
    ?assertEqual(7000, S1#file_state.updated_at).

apply_unknown_event_test() ->
    S0 = registered_state(),
    Event = #{event_type => <<"bogus_event_v1">>, data => <<"foo">>},
    S1 = file_aggregate:apply(S0, Event),
    ?assertEqual(S0, S1).

%% ===================================================================
%% Roundtrip tests
%% ===================================================================

full_file_lifecycle_test() ->
    S0 = file_state:new(<<"file-001">>),

    %% 1. Register
    RegPayload = #{
        command_type => <<"register_file">>,
        file_id    => <<"file-001">>,
        name       => <<"notes.txt">>,
        file_type  => <<"text">>,
        plugin     => <<"editor">>
    },
    {ok, [E1]} = file_aggregate:execute(S0, RegPayload),
    S1 = file_aggregate:apply(S0, E1),
    ?assertEqual(<<"notes.txt">>, S1#file_state.name),
    ?assertNotEqual(0, S1#file_state.status band ?FILE_INITIATED),

    %% 2. Rename
    RenPayload = #{
        command_type => <<"rename_file">>,
        file_id => <<"file-001">>,
        name => <<"diary.txt">>
    },
    {ok, [E2]} = file_aggregate:execute(S1, RenPayload),
    S2 = file_aggregate:apply(S1, E2),
    ?assertEqual(<<"diary.txt">>, S2#file_state.name),

    %% 3. Move
    MovePayload = #{
        command_type => <<"move_file">>,
        file_id => <<"file-001">>,
        folder_id => <<"folder-new">>
    },
    {ok, [E3]} = file_aggregate:execute(S2, MovePayload),
    S3 = file_aggregate:apply(S2, E3),
    ?assertEqual(<<"folder-new">>, S3#file_state.folder_id),

    %% 4. Star
    StarPayload = #{
        command_type => <<"star_file">>,
        file_id => <<"file-001">>
    },
    {ok, [E4]} = file_aggregate:execute(S3, StarPayload),
    S4 = file_aggregate:apply(S3, E4),
    ?assertEqual(true, S4#file_state.starred),

    %% 5. Unstar
    UnstarPayload = #{
        command_type => <<"unstar_file">>,
        file_id => <<"file-001">>
    },
    {ok, [E5]} = file_aggregate:execute(S4, UnstarPayload),
    S5 = file_aggregate:apply(S4, E5),
    ?assertEqual(false, S5#file_state.starred),
    %% STARRED bit cleared
    ?assertEqual(0, S5#file_state.status band ?FILE_STARRED),

    %% 6. Archive
    ArchivePayload = #{
        command_type => <<"archive_file">>,
        file_id => <<"file-001">>
    },
    {ok, [E6]} = file_aggregate:execute(S5, ArchivePayload),
    S6 = file_aggregate:apply(S5, E6),
    ?assertNotEqual(0, S6#file_state.status band ?FILE_ARCHIVED),

    %% Final state has expected flags
    ?assertNotEqual(0, S6#file_state.status band ?FILE_INITIATED),
    ?assertNotEqual(0, S6#file_state.status band ?FILE_RENAMED),
    ?assertNotEqual(0, S6#file_state.status band ?FILE_MOVED),
    ?assertNotEqual(0, S6#file_state.status band ?FILE_ARCHIVED),

    %% Archived rejects further commands
    ?assertEqual({error, file_archived},
                 file_aggregate:execute(S6, #{command_type => <<"star_file">>,
                                              file_id => <<"file-001">>})).

%% ===================================================================
%% Helpers
%% ===================================================================

registered_state() ->
    S0 = file_state:new(<<"file-001">>),
    Event = #{
        event_type => <<"file_registered_v1">>,
        file_id    => <<"file-001">>,
        name       => <<"notes.txt">>,
        file_type  => <<"text">>,
        plugin     => <<"editor">>,
        folder_id  => <<"folder-1">>,
        created_at => 1000
    },
    file_aggregate:apply(S0, Event).

starred_state() ->
    S1 = registered_state(),
    StarEvt = #{
        event_type => <<"file_starred_v1">>,
        file_id    => <<"file-001">>,
        starred_at => 2000
    },
    file_aggregate:apply(S1, StarEvt).

archived_state() ->
    S1 = registered_state(),
    ArchiveEvt = #{
        event_type  => <<"file_archived_v1">>,
        file_id     => <<"file-001">>,
        archived_at => 9000
    },
    file_aggregate:apply(S1, ArchiveEvt).
