-module(briefcase_item_aggregate_tests).
-include_lib("eunit/include/eunit.hrl").

-include("briefcase_item_status.hrl").
-include("briefcase_item_state.hrl").

%% ===================================================================
%% Happy Path: Execute Tests
%% ===================================================================

initiate_folder_test() ->
    State = briefcase_item_state:new(<<"item-1">>),
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<"My Folder">>,
        kind => <<"folder">>
    },
    {ok, [Event]} = briefcase_item_aggregate:execute(State, Payload),
    ?assertEqual(<<"briefcase_item_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"item-1">>, maps:get(item_id, Event)),
    ?assertEqual(<<"My Folder">>, maps:get(name, Event)),
    ?assertEqual(<<"folder">>, maps:get(kind, Event)).

initiate_blob_test() ->
    State = briefcase_item_state:new(<<"item-2">>),
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-2">>,
        name => <<"notes.txt">>,
        kind => <<"blob">>,
        plugin => <<"app_scribe">>,
        file_type => <<"text">>,
        mime_type => <<"text/plain">>,
        size => 1024,
        parent_id => <<"folder-1">>,
        icon => <<"file-text">>
    },
    {ok, [Event]} = briefcase_item_aggregate:execute(State, Payload),
    ?assertEqual(<<"briefcase_item_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"blob">>, maps:get(kind, Event)),
    ?assertEqual(<<"app_scribe">>, maps:get(plugin, Event)),
    ?assertEqual(<<"text">>, maps:get(file_type, Event)),
    ?assertEqual(<<"text/plain">>, maps:get(mime_type, Event)),
    ?assertEqual(1024, maps:get(size, Event)),
    ?assertEqual(<<"folder-1">>, maps:get(parent_id, Event)),
    ?assertEqual(<<"file-text">>, maps:get(icon, Event)).

initiate_symlink_test() ->
    State = briefcase_item_state:new(<<"item-3">>),
    Payload = #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-3">>,
        name => <<"shortcut">>,
        kind => <<"symlink">>,
        path => <<"/some/target/path">>
    },
    {ok, [Event]} = briefcase_item_aggregate:execute(State, Payload),
    ?assertEqual(<<"briefcase_item_initiated_v1">>, maps:get(event_type, Event)),
    ?assertEqual(<<"symlink">>, maps:get(kind, Event)),
    ?assertEqual(<<"/some/target/path">>, maps:get(path, Event)).

rename_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    {ok, [E1]} = briefcase_item_aggregate:execute(S0, initiate_folder_payload()),
    S1 = briefcase_item_aggregate:apply(S0, E1),
    {ok, [E2]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"rename_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<"Renamed Folder">>
    }),
    ?assertEqual(<<"briefcase_item_renamed_v1">>, maps:get(event_type, E2)),
    ?assertEqual(<<"Renamed Folder">>, maps:get(name, E2)).

move_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    {ok, [E1]} = briefcase_item_aggregate:execute(S0, initiate_folder_payload()),
    S1 = briefcase_item_aggregate:apply(S0, E1),
    {ok, [E2]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"move_briefcase_item">>,
        item_id => <<"item-1">>,
        parent_id => <<"new-parent">>
    }),
    ?assertEqual(<<"briefcase_item_moved_v1">>, maps:get(event_type, E2)),
    ?assertEqual(<<"new-parent">>, maps:get(parent_id, E2)).

star_test() ->
    S1 = initiated_state(),
    {ok, [E2]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"star_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    ?assertEqual(<<"briefcase_item_starred_v1">>, maps:get(event_type, E2)).

unstar_test() ->
    S1 = initiated_state(),
    {ok, [StarEvt]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"star_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    S2 = briefcase_item_aggregate:apply(S1, StarEvt),
    {ok, [E3]} = briefcase_item_aggregate:execute(S2, #{
        command_type => <<"unstar_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    ?assertEqual(<<"briefcase_item_unstarred_v1">>, maps:get(event_type, E3)).

archive_test() ->
    S1 = initiated_state(),
    {ok, [E2]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"archive_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    ?assertEqual(<<"briefcase_item_archived_v1">>, maps:get(event_type, E2)).

%% ===================================================================
%% Error Path: Execute Tests
%% ===================================================================

initiate_already_initiated_test() ->
    S1 = initiated_state(),
    ?assertEqual({error, item_already_initiated},
        briefcase_item_aggregate:execute(S1, initiate_folder_payload())).

rename_not_initiated_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    ?assertEqual({error, item_not_initiated},
        briefcase_item_aggregate:execute(S0, #{
            command_type => <<"rename_briefcase_item">>,
            item_id => <<"item-1">>,
            name => <<"New Name">>
        })).

rename_archived_test() ->
    S1 = initiated_state(),
    {ok, [ArchEvt]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"archive_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    S2 = briefcase_item_aggregate:apply(S1, ArchEvt),
    ?assertEqual({error, item_archived},
        briefcase_item_aggregate:execute(S2, #{
            command_type => <<"rename_briefcase_item">>,
            item_id => <<"item-1">>,
            name => <<"Nope">>
        })).

star_already_starred_test() ->
    S1 = initiated_state(),
    {ok, [StarEvt]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"star_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    S2 = briefcase_item_aggregate:apply(S1, StarEvt),
    ?assertEqual({error, already_starred},
        briefcase_item_aggregate:execute(S2, #{
            command_type => <<"star_briefcase_item">>,
            item_id => <<"item-1">>
        })).

unstar_not_starred_test() ->
    S1 = initiated_state(),
    ?assertEqual({error, not_starred},
        briefcase_item_aggregate:execute(S1, #{
            command_type => <<"unstar_briefcase_item">>,
            item_id => <<"item-1">>
        })).

archive_archived_test() ->
    S1 = initiated_state(),
    {ok, [ArchEvt]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"archive_briefcase_item">>,
        item_id => <<"item-1">>
    }),
    S2 = briefcase_item_aggregate:apply(S1, ArchEvt),
    ?assertEqual({error, item_archived},
        briefcase_item_aggregate:execute(S2, #{
            command_type => <<"archive_briefcase_item">>,
            item_id => <<"item-1">>
        })).

unknown_command_fresh_state_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    ?assertEqual({error, item_not_initiated},
        briefcase_item_aggregate:execute(S0, #{
            command_type => <<"bogus_command">>,
            item_id => <<"item-1">>
        })).

unknown_command_initiated_state_test() ->
    S1 = initiated_state(),
    ?assertEqual({error, unknown_command},
        briefcase_item_aggregate:execute(S1, #{
            command_type => <<"bogus_command">>,
            item_id => <<"item-1">>
        })).

%% ===================================================================
%% Apply Event Tests
%% ===================================================================

apply_initiated_sets_status_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    E = #{
        event_type => <<"briefcase_item_initiated_v1">>,
        item_id => <<"item-1">>,
        name => <<"Folder">>,
        kind => <<"folder">>,
        parent_id => undefined,
        plugin => undefined,
        file_type => undefined,
        icon => undefined,
        path => undefined,
        mime_type => undefined,
        size => 0,
        created_at => 1000
    },
    S1 = briefcase_item_aggregate:apply(S0, E),
    ?assertEqual(?ITEM_INITIATED, S1#briefcase_item_state.status),
    ?assertEqual(<<"item-1">>, S1#briefcase_item_state.item_id),
    ?assertEqual(<<"Folder">>, S1#briefcase_item_state.name),
    ?assertEqual(<<"folder">>, S1#briefcase_item_state.kind),
    ?assertEqual(false, S1#briefcase_item_state.starred),
    ?assertEqual(1000, S1#briefcase_item_state.created_at),
    ?assertEqual(1000, S1#briefcase_item_state.updated_at).

apply_renamed_sets_flag_test() ->
    S1 = initiated_state(),
    E = #{event_type => <<"briefcase_item_renamed_v1">>,
          item_id => <<"item-1">>, name => <<"New">>, renamed_at => 2000},
    S2 = briefcase_item_aggregate:apply(S1, E),
    ?assertEqual(<<"New">>, S2#briefcase_item_state.name),
    ?assertNotEqual(0, S2#briefcase_item_state.status band ?ITEM_RENAMED),
    ?assertEqual(2000, S2#briefcase_item_state.updated_at).

apply_moved_sets_flag_test() ->
    S1 = initiated_state(),
    E = #{event_type => <<"briefcase_item_moved_v1">>,
          item_id => <<"item-1">>, parent_id => <<"p2">>, moved_at => 3000},
    S2 = briefcase_item_aggregate:apply(S1, E),
    ?assertEqual(<<"p2">>, S2#briefcase_item_state.parent_id),
    ?assertNotEqual(0, S2#briefcase_item_state.status band ?ITEM_MOVED),
    ?assertEqual(3000, S2#briefcase_item_state.updated_at).

apply_starred_sets_flag_test() ->
    S1 = initiated_state(),
    E = #{event_type => <<"briefcase_item_starred_v1">>,
          item_id => <<"item-1">>, starred_at => 4000},
    S2 = briefcase_item_aggregate:apply(S1, E),
    ?assertEqual(true, S2#briefcase_item_state.starred),
    ?assertNotEqual(0, S2#briefcase_item_state.status band ?ITEM_STARRED),
    ?assertEqual(4000, S2#briefcase_item_state.updated_at).

apply_unstarred_clears_flag_test() ->
    S1 = initiated_state(),
    StarE = #{event_type => <<"briefcase_item_starred_v1">>,
              item_id => <<"item-1">>, starred_at => 4000},
    S2 = briefcase_item_aggregate:apply(S1, StarE),
    UnstarE = #{event_type => <<"briefcase_item_unstarred_v1">>,
                item_id => <<"item-1">>, unstarred_at => 5000},
    S3 = briefcase_item_aggregate:apply(S2, UnstarE),
    ?assertEqual(false, S3#briefcase_item_state.starred),
    ?assertEqual(5000, S3#briefcase_item_state.updated_at).

apply_archived_sets_flag_test() ->
    S1 = initiated_state(),
    E = #{event_type => <<"briefcase_item_archived_v1">>,
          item_id => <<"item-1">>, archived_at => 6000},
    S2 = briefcase_item_aggregate:apply(S1, E),
    ?assertNotEqual(0, S2#briefcase_item_state.status band ?ITEM_ARCHIVED),
    ?assertEqual(6000, S2#briefcase_item_state.updated_at).

apply_unknown_event_noop_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    E = #{event_type => <<"bogus_event_v99">>, foo => <<"bar">>},
    S1 = briefcase_item_aggregate:apply(S0, E),
    ?assertEqual(S0, S1).

%% ===================================================================
%% Roundtrip: Full Lifecycle
%% ===================================================================

full_lifecycle_test() ->
    S0 = briefcase_item_state:new(<<"item-1">>),

    %% Initiate
    {ok, [E1]} = briefcase_item_aggregate:execute(S0, initiate_folder_payload()),
    S1 = briefcase_item_aggregate:apply(S0, E1),
    ?assertEqual(<<"My Folder">>, S1#briefcase_item_state.name),
    ?assertEqual(?ITEM_INITIATED, S1#briefcase_item_state.status),

    %% Rename
    {ok, [E2]} = briefcase_item_aggregate:execute(S1, #{
        command_type => <<"rename_briefcase_item">>,
        item_id => <<"item-1">>, name => <<"Renamed">>
    }),
    S2 = briefcase_item_aggregate:apply(S1, E2),
    ?assertEqual(<<"Renamed">>, S2#briefcase_item_state.name),

    %% Move
    {ok, [E3]} = briefcase_item_aggregate:execute(S2, #{
        command_type => <<"move_briefcase_item">>,
        item_id => <<"item-1">>, parent_id => <<"parent-99">>
    }),
    S3 = briefcase_item_aggregate:apply(S2, E3),
    ?assertEqual(<<"parent-99">>, S3#briefcase_item_state.parent_id),

    %% Star
    {ok, [E4]} = briefcase_item_aggregate:execute(S3, #{
        command_type => <<"star_briefcase_item">>, item_id => <<"item-1">>
    }),
    S4 = briefcase_item_aggregate:apply(S3, E4),
    ?assertEqual(true, S4#briefcase_item_state.starred),

    %% Unstar
    {ok, [E5]} = briefcase_item_aggregate:execute(S4, #{
        command_type => <<"unstar_briefcase_item">>, item_id => <<"item-1">>
    }),
    S5 = briefcase_item_aggregate:apply(S4, E5),
    ?assertEqual(false, S5#briefcase_item_state.starred),

    %% Archive
    {ok, [E6]} = briefcase_item_aggregate:execute(S5, #{
        command_type => <<"archive_briefcase_item">>, item_id => <<"item-1">>
    }),
    S6 = briefcase_item_aggregate:apply(S5, E6),
    ?assertNotEqual(0, S6#briefcase_item_state.status band ?ITEM_ARCHIVED),

    %% Verify final state has all flags
    ?assertNotEqual(0, S6#briefcase_item_state.status band ?ITEM_INITIATED),
    ?assertNotEqual(0, S6#briefcase_item_state.status band ?ITEM_RENAMED),
    ?assertNotEqual(0, S6#briefcase_item_state.status band ?ITEM_MOVED),
    ?assertNotEqual(0, S6#briefcase_item_state.status band ?ITEM_ARCHIVED),
    ?assertEqual(<<"Renamed">>, S6#briefcase_item_state.name),
    ?assertEqual(<<"parent-99">>, S6#briefcase_item_state.parent_id).

%% ===================================================================
%% Helpers
%% ===================================================================

initiate_folder_payload() ->
    #{
        command_type => <<"initiate_briefcase_item">>,
        item_id => <<"item-1">>,
        name => <<"My Folder">>,
        kind => <<"folder">>
    }.

initiated_state() ->
    S0 = briefcase_item_state:new(<<"item-1">>),
    {ok, [E]} = briefcase_item_aggregate:execute(S0, initiate_folder_payload()),
    briefcase_item_aggregate:apply(S0, E).
