%%% @doc Merged projection: all folder lifecycle events -> briefcase_folder_tree ETS.
%%%
%%% Handles folder_initiated_v1, folder_renamed_v1, folder_moved_v1,
%%% and folder_archived_v1 in a single projection to eliminate race
%%% conditions between separate projections writing to the same ETS table.
%%% @end
-module(folder_lifecycle_to_tree).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

interested_in() ->
    [<<"folder_initiated_v1">>,
     <<"folder_renamed_v1">>,
     <<"folder_moved_v1">>,
     <<"folder_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => briefcase_folder_tree}),
    {ok, #{}, RM}.

%% --- folder_initiated_v1: INSERT new folder ---

project(#{event_type := <<"folder_initiated_v1">>, data := Data},
        _Metadata, State, RM) ->
    FolderId = gf(folder_id, Data),
    CreatedAt = gf(created_at, Data),
    Folder = #{
        folder_id  => FolderId,
        name       => gf(name, Data),
        parent_id  => gf(parent_id, Data),
        icon       => gf(icon, Data),
        status     => 1,
        created_at => CreatedAt,
        updated_at => CreatedAt
    },
    project_briefcase_store:put_folder(FolderId, Folder),
    {ok, State, RM};

%% --- folder_renamed_v1: update name, status bor 2 ---

project(#{event_type := <<"folder_renamed_v1">>, data := Data},
        _Metadata, State, RM) ->
    FolderId = gf(folder_id, Data),
    case project_briefcase_store:get_folder(FolderId) of
        {ok, #{status := S} = Folder} ->
            Updated = Folder#{
                name       => gf(name, Data),
                status     => S bor 2,
                updated_at => gf(renamed_at, Data)
            },
            project_briefcase_store:put_folder(FolderId, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- folder_moved_v1: update parent_id, status bor 4 ---

project(#{event_type := <<"folder_moved_v1">>, data := Data},
        _Metadata, State, RM) ->
    FolderId = gf(folder_id, Data),
    case project_briefcase_store:get_folder(FolderId) of
        {ok, #{status := S} = Folder} ->
            Updated = Folder#{
                parent_id  => gf(parent_id, Data),
                status     => S bor 4,
                updated_at => gf(moved_at, Data)
            },
            project_briefcase_store:put_folder(FolderId, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- folder_archived_v1: set archived flag, remove from tree ---

project(#{event_type := <<"folder_archived_v1">>, data := Data},
        _Metadata, State, RM) ->
    FolderId = gf(folder_id, Data),
    case project_briefcase_store:get_folder(FolderId) of
        {ok, #{status := S} = Folder} ->
            _Archived = Folder#{
                status     => S bor 8,
                updated_at => gf(archived_at, Data)
            },
            project_briefcase_store:delete_folder(FolderId),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- Unknown event type: skip ---

project(_Event, _Metadata, State, RM) ->
    {skip, State, RM}.

%% --- Helpers ---

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
