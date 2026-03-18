-module(folder_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").

-include("folder_status.hrl").
-include("folder_state.hrl").

%% ===================================================================
%% Execute tests — happy path
%% ===================================================================

create_folder_test() ->
    State = folder_state:new(<<"folder-123">>),
    Payload = #{
        command_type => <<"create_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Work">>,
        parent_id => <<"parent-1">>,
        icon => <<"\xF0\x9F\x93\x81">>
    },
    {ok, [Event]} = folder_aggregate:execute(State, Payload),
    ?assertEqual(<<"folder_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"folder-123">>, maps:get(folder_id, Event)),
    ?assertEqual(<<"Work">>, maps:get(name, Event)),
    ?assertEqual(<<"parent-1">>, maps:get(parent_id, Event)),
    ?assert(is_integer(maps:get(created_at, Event))).

rename_folder_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"rename_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Personal">>
    },
    {ok, [Event]} = folder_aggregate:execute(State, Payload),
    ?assertEqual(<<"folder_renamed_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"Personal">>, maps:get(name, Event)),
    ?assert(is_integer(maps:get(renamed_at, Event))).

move_folder_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"move_folder">>,
        folder_id => <<"folder-123">>,
        parent_id => <<"new-parent">>
    },
    {ok, [Event]} = folder_aggregate:execute(State, Payload),
    ?assertEqual(<<"folder_moved_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"new-parent">>, maps:get(parent_id, Event)),
    ?assert(is_integer(maps:get(moved_at, Event))).

move_to_root_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"move_folder">>,
        folder_id => <<"folder-123">>
    },
    {ok, [Event]} = folder_aggregate:execute(State, Payload),
    ?assertEqual(<<"folder_moved_v1">>, maps:get(event_type, Event)),
    %% parent_id omitted from event map when undefined (maybe_put)
    ?assertEqual(error, maps:find(parent_id, Event)).

archive_folder_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"archive_folder">>,
        folder_id => <<"folder-123">>
    },
    {ok, [Event]} = folder_aggregate:execute(State, Payload),
    ?assertEqual(<<"folder_archived_v1">>, maps:get(event_type, Event)),
    ?assert(is_integer(maps:get(archived_at, Event))).

%% ===================================================================
%% Execute tests — errors
%% ===================================================================

create_already_initiated_test() ->
    State = initiated_state(),
    Payload = #{
        command_type => <<"create_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Dup">>
    },
    ?assertEqual({error, folder_already_initiated},
                 folder_aggregate:execute(State, Payload)).

rename_not_initiated_test() ->
    State = folder_state:new(<<"folder-123">>),
    Payload = #{
        command_type => <<"rename_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Nope">>
    },
    ?assertEqual({error, folder_not_initiated},
                 folder_aggregate:execute(State, Payload)).

move_not_initiated_test() ->
    State = folder_state:new(<<"folder-123">>),
    Payload = #{
        command_type => <<"move_folder">>,
        folder_id => <<"folder-123">>,
        parent_id => <<"somewhere">>
    },
    ?assertEqual({error, folder_not_initiated},
                 folder_aggregate:execute(State, Payload)).

rename_archived_test() ->
    State = archived_state(),
    Payload = #{
        command_type => <<"rename_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Nope">>
    },
    ?assertEqual({error, folder_archived},
                 folder_aggregate:execute(State, Payload)).

move_archived_test() ->
    State = archived_state(),
    Payload = #{
        command_type => <<"move_folder">>,
        folder_id => <<"folder-123">>,
        parent_id => <<"somewhere">>
    },
    ?assertEqual({error, folder_archived},
                 folder_aggregate:execute(State, Payload)).

archive_already_archived_test() ->
    State = archived_state(),
    Payload = #{
        command_type => <<"archive_folder">>,
        folder_id => <<"folder-123">>
    },
    ?assertEqual({error, folder_archived},
                 folder_aggregate:execute(State, Payload)).

unknown_command_fresh_test() ->
    State = folder_state:new(<<"folder-123">>),
    ?assertEqual({error, folder_not_initiated},
                 folder_aggregate:execute(State, #{command_type => <<"bogus">>})).

unknown_command_initiated_test() ->
    State = initiated_state(),
    ?assertEqual({error, unknown_command},
                 folder_aggregate:execute(State, #{command_type => <<"bogus">>})).

%% ===================================================================
%% Apply event tests
%% ===================================================================

apply_initiated_test() ->
    S0 = folder_state:new(<<"folder-123">>),
    Event = #{
        event_type => <<"folder_initiated_v1">>,
        folder_id  => <<"folder-123">>,
        name       => <<"Work">>,
        parent_id  => <<"parent-1">>,
        icon       => <<"\xF0\x9F\x93\x81">>,
        created_at => 1000
    },
    S1 = folder_aggregate:apply(S0, Event),
    ?assertEqual(<<"folder-123">>, S1#folder_state.folder_id),
    ?assertEqual(<<"Work">>, S1#folder_state.name),
    ?assertEqual(<<"parent-1">>, S1#folder_state.parent_id),
    ?assertEqual(<<"\xF0\x9F\x93\x81">>, S1#folder_state.icon),
    ?assertEqual(?FOLDER_INITIATED, S1#folder_state.status),
    ?assertEqual(1000, S1#folder_state.created_at),
    ?assertEqual(1000, S1#folder_state.updated_at).

apply_renamed_test() ->
    S0 = initiated_state(),
    Event = #{
        event_type => <<"folder_renamed_v1">>,
        folder_id  => <<"folder-123">>,
        name       => <<"Personal">>,
        renamed_at => 2000
    },
    S1 = folder_aggregate:apply(S0, Event),
    ?assertEqual(<<"Personal">>, S1#folder_state.name),
    ?assertNotEqual(0, S1#folder_state.status band ?FOLDER_RENAMED),
    ?assertEqual(2000, S1#folder_state.updated_at).

apply_moved_test() ->
    S0 = initiated_state(),
    Event = #{
        event_type => <<"folder_moved_v1">>,
        folder_id  => <<"folder-123">>,
        parent_id  => <<"new-parent">>,
        moved_at   => 3000
    },
    S1 = folder_aggregate:apply(S0, Event),
    ?assertEqual(<<"new-parent">>, S1#folder_state.parent_id),
    ?assertNotEqual(0, S1#folder_state.status band ?FOLDER_MOVED),
    ?assertEqual(3000, S1#folder_state.updated_at).

apply_archived_test() ->
    S0 = initiated_state(),
    Event = #{
        event_type  => <<"folder_archived_v1">>,
        folder_id   => <<"folder-123">>,
        archived_at => 4000
    },
    S1 = folder_aggregate:apply(S0, Event),
    ?assertNotEqual(0, S1#folder_state.status band ?FOLDER_ARCHIVED),
    ?assertEqual(4000, S1#folder_state.updated_at).

apply_unknown_event_test() ->
    S0 = initiated_state(),
    Event = #{event_type => <<"bogus_event_v1">>, data => <<"foo">>},
    S1 = folder_aggregate:apply(S0, Event),
    ?assertEqual(S0, S1).

%% ===================================================================
%% Roundtrip tests
%% ===================================================================

full_lifecycle_test() ->
    S0 = folder_state:new(<<"folder-123">>),

    %% 1. Create
    CreatePayload = #{
        command_type => <<"create_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Work">>,
        parent_id => <<"root">>
    },
    {ok, [E1]} = folder_aggregate:execute(S0, CreatePayload),
    S1 = folder_aggregate:apply(S0, E1),
    ?assertEqual(<<"Work">>, S1#folder_state.name),
    ?assertNotEqual(0, S1#folder_state.status band ?FOLDER_INITIATED),

    %% 2. Rename
    RenamePayload = #{
        command_type => <<"rename_folder">>,
        folder_id => <<"folder-123">>,
        name => <<"Personal">>
    },
    {ok, [E2]} = folder_aggregate:execute(S1, RenamePayload),
    S2 = folder_aggregate:apply(S1, E2),
    ?assertEqual(<<"Personal">>, S2#folder_state.name),
    ?assertNotEqual(0, S2#folder_state.status band ?FOLDER_RENAMED),

    %% 3. Move
    MovePayload = #{
        command_type => <<"move_folder">>,
        folder_id => <<"folder-123">>,
        parent_id => <<"archive-parent">>
    },
    {ok, [E3]} = folder_aggregate:execute(S2, MovePayload),
    S3 = folder_aggregate:apply(S2, E3),
    ?assertEqual(<<"archive-parent">>, S3#folder_state.parent_id),
    ?assertNotEqual(0, S3#folder_state.status band ?FOLDER_MOVED),

    %% 4. Archive
    ArchivePayload = #{
        command_type => <<"archive_folder">>,
        folder_id => <<"folder-123">>
    },
    {ok, [E4]} = folder_aggregate:execute(S3, ArchivePayload),
    S4 = folder_aggregate:apply(S3, E4),
    ?assertNotEqual(0, S4#folder_state.status band ?FOLDER_ARCHIVED),

    %% Final state has all flags
    ?assertNotEqual(0, S4#folder_state.status band ?FOLDER_INITIATED),
    ?assertNotEqual(0, S4#folder_state.status band ?FOLDER_RENAMED),
    ?assertNotEqual(0, S4#folder_state.status band ?FOLDER_MOVED),
    ?assertNotEqual(0, S4#folder_state.status band ?FOLDER_ARCHIVED),

    %% Archived state rejects further commands
    ?assertEqual({error, folder_archived},
                 folder_aggregate:execute(S4, #{command_type => <<"rename_folder">>,
                                                folder_id => <<"folder-123">>,
                                                name => <<"Nope">>})).

%% ===================================================================
%% Helpers
%% ===================================================================

initiated_state() ->
    S0 = folder_state:new(<<"folder-123">>),
    Event = #{
        event_type => <<"folder_initiated_v1">>,
        folder_id  => <<"folder-123">>,
        name       => <<"Work">>,
        parent_id  => <<"root">>,
        icon       => <<"\xF0\x9F\x93\x81">>,
        created_at => 1000
    },
    folder_aggregate:apply(S0, Event).

archived_state() ->
    S1 = initiated_state(),
    ArchiveEvt = #{
        event_type  => <<"folder_archived_v1">>,
        folder_id   => <<"folder-123">>,
        archived_at => 5000
    },
    folder_aggregate:apply(S1, ArchiveEvt).
