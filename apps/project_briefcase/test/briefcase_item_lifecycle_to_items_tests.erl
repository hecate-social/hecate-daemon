-module(briefcase_item_lifecycle_to_items_tests).
-include_lib("eunit/include/eunit.hrl").

-include_lib("guide_briefcase_lifecycle/include/briefcase_item_status.hrl").

-define(TABLE, briefcase_items).
-define(ITEM_ID, <<"item-1">>).

%% ===================================================================
%% Setup / Teardown
%% ===================================================================

setup() ->
    catch ets:delete(?TABLE),
    ?TABLE = ets:new(?TABLE, [set, public, named_table, {read_concurrency, true}]),
    ok.

cleanup() ->
    catch ets:delete(?TABLE),
    ok.

%% ===================================================================
%% Helpers
%% ===================================================================

make_initiated_data() ->
    make_initiated_data(?ITEM_ID).

make_initiated_data(ItemId) ->
    #{
        item_id    => ItemId,
        name       => <<"My Folder">>,
        kind       => <<"folder">>,
        parent_id  => undefined,
        plugin     => undefined,
        file_type  => undefined,
        icon       => undefined,
        path       => undefined,
        mime_type  => undefined,
        size       => 0,
        created_at => 1000
    }.

wrap_event(Data) ->
    #{data => Data, event_type => maps:get(event_type, Data)}.

project(Data, State, RM) ->
    briefcase_item_lifecycle_to_items:project(wrap_event(Data), #{}, State, RM).

%% ===================================================================
%% Projection Tests
%% ===================================================================

initiated_projects_to_ets_test() ->
    setup(),
    try
        Data = (make_initiated_data())#{event_type => <<"briefcase_item_initiated_v1">>},
        {ok, _S, _RM} = project(Data, #{}, undefined),
        [{?ITEM_ID, Item}] = ets:lookup(?TABLE, ?ITEM_ID),
        ?assertEqual(?ITEM_ID, maps:get(item_id, Item)),
        ?assertEqual(<<"My Folder">>, maps:get(name, Item)),
        ?assertEqual(<<"folder">>, maps:get(kind, Item)),
        ?assertEqual(false, maps:get(starred, Item)),
        ?assertEqual(?ITEM_INITIATED, maps:get(status, Item)),
        ?assertEqual(1000, maps:get(created_at, Item)),
        ?assertEqual(1000, maps:get(updated_at, Item))
    after
        cleanup()
    end.

renamed_updates_name_test() ->
    setup(),
    try
        InitData = (make_initiated_data())#{event_type => <<"briefcase_item_initiated_v1">>},
        {ok, S1, RM1} = project(InitData, #{}, undefined),
        RenameData = #{
            event_type => <<"briefcase_item_renamed_v1">>,
            item_id => ?ITEM_ID,
            name => <<"Renamed">>,
            renamed_at => 2000
        },
        {ok, _S2, _RM2} = project(RenameData, S1, RM1),
        [{?ITEM_ID, Item}] = ets:lookup(?TABLE, ?ITEM_ID),
        ?assertEqual(<<"Renamed">>, maps:get(name, Item)),
        ?assertNotEqual(0, maps:get(status, Item) band ?ITEM_RENAMED),
        ?assertEqual(2000, maps:get(updated_at, Item))
    after
        cleanup()
    end.

moved_updates_parent_test() ->
    setup(),
    try
        InitData = (make_initiated_data())#{event_type => <<"briefcase_item_initiated_v1">>},
        {ok, S1, RM1} = project(InitData, #{}, undefined),
        MoveData = #{
            event_type => <<"briefcase_item_moved_v1">>,
            item_id => ?ITEM_ID,
            parent_id => <<"new-parent">>,
            moved_at => 3000
        },
        {ok, _S2, _RM2} = project(MoveData, S1, RM1),
        [{?ITEM_ID, Item}] = ets:lookup(?TABLE, ?ITEM_ID),
        ?assertEqual(<<"new-parent">>, maps:get(parent_id, Item)),
        ?assertNotEqual(0, maps:get(status, Item) band ?ITEM_MOVED),
        ?assertEqual(3000, maps:get(updated_at, Item))
    after
        cleanup()
    end.

starred_test() ->
    setup(),
    try
        InitData = (make_initiated_data())#{event_type => <<"briefcase_item_initiated_v1">>},
        {ok, S1, RM1} = project(InitData, #{}, undefined),
        StarData = #{
            event_type => <<"briefcase_item_starred_v1">>,
            item_id => ?ITEM_ID,
            starred_at => 4000
        },
        {ok, _S2, _RM2} = project(StarData, S1, RM1),
        [{?ITEM_ID, Item}] = ets:lookup(?TABLE, ?ITEM_ID),
        ?assertEqual(true, maps:get(starred, Item)),
        ?assertNotEqual(0, maps:get(status, Item) band ?ITEM_STARRED),
        ?assertEqual(4000, maps:get(updated_at, Item))
    after
        cleanup()
    end.

unstarred_test() ->
    setup(),
    try
        InitData = (make_initiated_data())#{event_type => <<"briefcase_item_initiated_v1">>},
        {ok, S1, RM1} = project(InitData, #{}, undefined),
        StarData = #{
            event_type => <<"briefcase_item_starred_v1">>,
            item_id => ?ITEM_ID,
            starred_at => 4000
        },
        {ok, S2, RM2} = project(StarData, S1, RM1),
        UnstarData = #{
            event_type => <<"briefcase_item_unstarred_v1">>,
            item_id => ?ITEM_ID,
            unstarred_at => 5000
        },
        {ok, _S3, _RM3} = project(UnstarData, S2, RM2),
        [{?ITEM_ID, Item}] = ets:lookup(?TABLE, ?ITEM_ID),
        ?assertEqual(false, maps:get(starred, Item)),
        ?assertEqual(5000, maps:get(updated_at, Item))
    after
        cleanup()
    end.

archived_deletes_from_ets_test() ->
    setup(),
    try
        InitData = (make_initiated_data())#{event_type => <<"briefcase_item_initiated_v1">>},
        {ok, S1, RM1} = project(InitData, #{}, undefined),
        ArchData = #{
            event_type => <<"briefcase_item_archived_v1">>,
            item_id => ?ITEM_ID,
            archived_at => 6000
        },
        {ok, _S2, _RM2} = project(ArchData, S1, RM1),
        ?assertEqual([], ets:lookup(?TABLE, ?ITEM_ID))
    after
        cleanup()
    end.

skip_on_not_found_test() ->
    setup(),
    try
        RenameData = #{
            event_type => <<"briefcase_item_renamed_v1">>,
            item_id => <<"nonexistent">>,
            name => <<"Ghost">>,
            renamed_at => 9000
        },
        {skip, _S, _RM} = project(RenameData, #{}, undefined)
    after
        cleanup()
    end.

unknown_event_noop_test() ->
    setup(),
    try
        Data = #{event_type => <<"bogus_event_v1">>, item_id => <<"x">>},
        {ok, _S, _RM} = project(Data, #{}, undefined)
    after
        cleanup()
    end.
