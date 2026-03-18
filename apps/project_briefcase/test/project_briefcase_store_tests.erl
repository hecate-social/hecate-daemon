-module(project_briefcase_store_tests).
-compile({no_auto_import, [put/2]}).
-include_lib("eunit/include/eunit.hrl").

-define(TABLE, briefcase_items).
-define(ARCHIVED, 8).

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

make_item(Id, Name, Kind, ParentId) ->
    make_item(Id, Name, Kind, ParentId, #{}).

make_item(Id, Name, Kind, ParentId, Overrides) ->
    Base = #{
        item_id    => Id,
        name       => Name,
        kind       => Kind,
        parent_id  => ParentId,
        plugin     => undefined,
        file_type  => undefined,
        icon       => undefined,
        path       => undefined,
        mime_type  => undefined,
        size       => 0,
        starred    => false,
        status     => 1,
        created_at => 1000,
        updated_at => 1000
    },
    maps:merge(Base, Overrides).

put(Id, Item) ->
    project_briefcase_store:put_item(Id, Item).

%% ===================================================================
%% Put / Get Tests
%% ===================================================================

put_and_get_item_test() ->
    setup(),
    try
        Item = make_item(<<"i1">>, <<"Docs">>, <<"folder">>, undefined),
        ok = put(<<"i1">>, Item),
        ?assertEqual({ok, Item}, project_briefcase_store:get_item(<<"i1">>))
    after
        cleanup()
    end.

get_missing_test() ->
    setup(),
    try
        ?assertEqual({error, not_found}, project_briefcase_store:get_item(<<"nope">>))
    after
        cleanup()
    end.

%% ===================================================================
%% List Items Tests
%% ===================================================================

list_items_all_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"A">>, <<"folder">>, undefined, #{updated_at => 1000})),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"B">>, <<"blob">>, <<"i1">>, #{updated_at => 2000})),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"C">>, <<"blob">>, <<"i1">>, #{updated_at => 3000})),
        {ok, Items} = project_briefcase_store:list_items(#{}),
        ?assertEqual(3, length(Items)),
        %% Sorted by updated_at descending
        [First | _] = Items,
        ?assertEqual(<<"i3">>, maps:get(item_id, First))
    after
        cleanup()
    end.

list_items_by_parent_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"Root">>, <<"folder">>, undefined)),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"Child1">>, <<"blob">>, <<"i1">>)),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"Child2">>, <<"blob">>, <<"i1">>)),
        ok = put(<<"i4">>, make_item(<<"i4">>, <<"Other">>, <<"blob">>, <<"other">>)),
        {ok, Items} = project_briefcase_store:list_items(#{parent_id => <<"i1">>}),
        ?assertEqual(2, length(Items)),
        Ids = [maps:get(item_id, I) || I <- Items],
        ?assert(lists:member(<<"i2">>, Ids)),
        ?assert(lists:member(<<"i3">>, Ids))
    after
        cleanup()
    end.

list_items_parent_all_filter_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"A">>, <<"folder">>, undefined)),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"B">>, <<"blob">>, <<"i1">>)),
        {ok, Items} = project_briefcase_store:list_items(#{parent_id => <<"all">>}),
        ?assertEqual(2, length(Items))
    after
        cleanup()
    end.

list_items_starred_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"A">>, <<"folder">>, undefined, #{starred => true})),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"B">>, <<"blob">>, undefined, #{starred => false})),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"C">>, <<"blob">>, undefined, #{starred => true})),
        {ok, Items} = project_briefcase_store:list_items(#{starred => true}),
        ?assertEqual(2, length(Items)),
        Ids = [maps:get(item_id, I) || I <- Items],
        ?assert(lists:member(<<"i1">>, Ids)),
        ?assert(lists:member(<<"i3">>, Ids))
    after
        cleanup()
    end.

list_items_search_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"Meeting Notes">>, <<"blob">>, undefined)),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"Photos">>, <<"folder">>, undefined)),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"Daily Notes">>, <<"blob">>, undefined)),
        {ok, Items} = project_briefcase_store:list_items(#{search => <<"notes">>}),
        ?assertEqual(2, length(Items)),
        Ids = [maps:get(item_id, I) || I <- Items],
        ?assert(lists:member(<<"i1">>, Ids)),
        ?assert(lists:member(<<"i3">>, Ids))
    after
        cleanup()
    end.

list_items_by_kind_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"F1">>, <<"folder">>, undefined)),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"B1">>, <<"blob">>, undefined)),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"F2">>, <<"folder">>, undefined)),
        {ok, Items} = project_briefcase_store:list_items(#{kind => <<"folder">>}),
        ?assertEqual(2, length(Items))
    after
        cleanup()
    end.

list_items_by_file_type_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"A">>, <<"blob">>, undefined, #{file_type => <<"image">>})),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"B">>, <<"blob">>, undefined, #{file_type => <<"text">>})),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"C">>, <<"blob">>, undefined, #{file_type => <<"image">>})),
        {ok, Items} = project_briefcase_store:list_items(#{file_type => <<"image">>}),
        ?assertEqual(2, length(Items))
    after
        cleanup()
    end.

%% ===================================================================
%% List Folders / Children Tests
%% ===================================================================

list_folders_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"F1">>, <<"folder">>, undefined)),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"B1">>, <<"blob">>, undefined)),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"F2">>, <<"folder">>, undefined)),
        {ok, Folders} = project_briefcase_store:list_folders(),
        ?assertEqual(2, length(Folders)),
        Kinds = [maps:get(kind, F) || F <- Folders],
        ?assertEqual([<<"folder">>, <<"folder">>], Kinds)
    after
        cleanup()
    end.

list_children_test() ->
    setup(),
    try
        ok = put(<<"p1">>, make_item(<<"p1">>, <<"Parent">>, <<"folder">>, undefined)),
        ok = put(<<"c1">>, make_item(<<"c1">>, <<"Child1">>, <<"blob">>, <<"p1">>)),
        ok = put(<<"c2">>, make_item(<<"c2">>, <<"Child2">>, <<"blob">>, <<"p1">>)),
        ok = put(<<"o1">>, make_item(<<"o1">>, <<"Other">>, <<"blob">>, <<"other">>)),
        {ok, Children} = project_briefcase_store:list_children(<<"p1">>),
        ?assertEqual(2, length(Children))
    after
        cleanup()
    end.

count_children_test() ->
    setup(),
    try
        ok = put(<<"p1">>, make_item(<<"p1">>, <<"Parent">>, <<"folder">>, undefined)),
        ok = put(<<"c1">>, make_item(<<"c1">>, <<"A">>, <<"blob">>, <<"p1">>)),
        ok = put(<<"c2">>, make_item(<<"c2">>, <<"B">>, <<"blob">>, <<"p1">>)),
        ok = put(<<"c3">>, make_item(<<"c3">>, <<"C">>, <<"blob">>, <<"p1">>)),
        ?assertEqual(3, project_briefcase_store:count_children(<<"p1">>))
    after
        cleanup()
    end.

count_children_empty_test() ->
    setup(),
    try
        ?assertEqual(0, project_briefcase_store:count_children(<<"empty">>))
    after
        cleanup()
    end.

%% ===================================================================
%% Archived Items Excluded Tests
%% ===================================================================

archived_excluded_from_list_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"Active">>, <<"folder">>, undefined)),
        ok = put(<<"i2">>, make_item(<<"i2">>, <<"Archived">>, <<"folder">>, undefined,
            #{status => 1 bor ?ARCHIVED})),
        ok = put(<<"i3">>, make_item(<<"i3">>, <<"Also Active">>, <<"blob">>, undefined)),
        {ok, Items} = project_briefcase_store:list_items(#{}),
        ?assertEqual(2, length(Items)),
        Ids = [maps:get(item_id, I) || I <- Items],
        ?assertNot(lists:member(<<"i2">>, Ids))
    after
        cleanup()
    end.

archived_excluded_from_folders_test() ->
    setup(),
    try
        ok = put(<<"f1">>, make_item(<<"f1">>, <<"Good">>, <<"folder">>, undefined)),
        ok = put(<<"f2">>, make_item(<<"f2">>, <<"Dead">>, <<"folder">>, undefined,
            #{status => 1 bor ?ARCHIVED})),
        {ok, Folders} = project_briefcase_store:list_folders(),
        ?assertEqual(1, length(Folders)),
        ?assertEqual(<<"f1">>, maps:get(item_id, hd(Folders)))
    after
        cleanup()
    end.

archived_excluded_from_children_test() ->
    setup(),
    try
        ok = put(<<"c1">>, make_item(<<"c1">>, <<"Live">>, <<"blob">>, <<"p1">>)),
        ok = put(<<"c2">>, make_item(<<"c2">>, <<"Dead">>, <<"blob">>, <<"p1">>,
            #{status => 1 bor ?ARCHIVED})),
        {ok, Children} = project_briefcase_store:list_children(<<"p1">>),
        ?assertEqual(1, length(Children)),
        ?assertEqual(0, project_briefcase_store:count_children(<<"p1">>) - length(Children))
    after
        cleanup()
    end.

%% ===================================================================
%% Delete Tests
%% ===================================================================

delete_item_test() ->
    setup(),
    try
        ok = put(<<"i1">>, make_item(<<"i1">>, <<"Doomed">>, <<"blob">>, undefined)),
        {ok, _} = project_briefcase_store:get_item(<<"i1">>),
        ok = project_briefcase_store:delete_item(<<"i1">>),
        ?assertEqual({error, not_found}, project_briefcase_store:get_item(<<"i1">>))
    after
        cleanup()
    end.
