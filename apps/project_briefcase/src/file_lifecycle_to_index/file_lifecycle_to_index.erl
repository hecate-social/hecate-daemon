%%% @doc Merged projection: all file lifecycle events -> briefcase_file_index ETS.
%%%
%%% Handles file_registered_v1, file_imported_v1, file_renamed_v1,
%%% file_moved_v1, file_starred_v1, file_unstarred_v1, and file_archived_v1
%%% in a single projection to eliminate race conditions.
%%% @end
-module(file_lifecycle_to_index).
-behaviour(evoq_projection).
-export([interested_in/0, init/1, project/4]).

interested_in() ->
    [<<"file_registered_v1">>,
     <<"file_imported_v1">>,
     <<"file_renamed_v1">>,
     <<"file_moved_v1">>,
     <<"file_starred_v1">>,
     <<"file_unstarred_v1">>,
     <<"file_archived_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => briefcase_file_index}),
    {ok, #{}, RM}.

%% --- file_registered_v1: INSERT new file (no blob yet) ---

project(#{event_type := <<"file_registered_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    CreatedAt = gf(created_at, Data),
    File = #{
        file_id    => FileId,
        name       => gf(name, Data),
        folder_id  => gf(folder_id, Data),
        file_type  => gf(file_type, Data),
        plugin     => gf(plugin, Data),
        icon       => gf(icon, Data),
        blob_id    => undefined,
        size       => 0,
        mime_type  => undefined,
        starred    => false,
        status     => 1,
        created_at => CreatedAt,
        updated_at => CreatedAt
    },
    project_briefcase_store:put_file(FileId, File),
    {ok, State, RM};

%% --- file_imported_v1: INSERT file with blob data (INITIATED bor IMPORTED = 33) ---

project(#{event_type := <<"file_imported_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    CreatedAt = gf(created_at, Data),
    File = #{
        file_id    => FileId,
        name       => gf(name, Data),
        folder_id  => gf(folder_id, Data),
        file_type  => gf(file_type, Data),
        plugin     => gf(plugin, Data),
        icon       => gf(icon, Data),
        blob_id    => gf(blob_id, Data),
        size       => gf(size, Data, 0),
        mime_type  => gf(mime_type, Data),
        starred    => false,
        status     => 1 bor 32,
        created_at => CreatedAt,
        updated_at => CreatedAt
    },
    project_briefcase_store:put_file(FileId, File),
    {ok, State, RM};

%% --- file_renamed_v1: update name, status bor 2 ---

project(#{event_type := <<"file_renamed_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    case project_briefcase_store:get_file(FileId) of
        {ok, #{status := S} = File} ->
            Updated = File#{
                name       => gf(name, Data),
                status     => S bor 2,
                updated_at => gf(renamed_at, Data)
            },
            project_briefcase_store:put_file(FileId, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- file_moved_v1: update folder_id, status bor 4 ---

project(#{event_type := <<"file_moved_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    case project_briefcase_store:get_file(FileId) of
        {ok, #{status := S} = File} ->
            Updated = File#{
                folder_id  => gf(folder_id, Data),
                status     => S bor 4,
                updated_at => gf(moved_at, Data)
            },
            project_briefcase_store:put_file(FileId, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- file_starred_v1: set starred, status bor 16 ---

project(#{event_type := <<"file_starred_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    case project_briefcase_store:get_file(FileId) of
        {ok, #{status := S} = File} ->
            Updated = File#{
                starred    => true,
                status     => S bor 16,
                updated_at => gf(starred_at, Data)
            },
            project_briefcase_store:put_file(FileId, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- file_unstarred_v1: clear starred ---

project(#{event_type := <<"file_unstarred_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    case project_briefcase_store:get_file(FileId) of
        {ok, File} ->
            Updated = File#{
                starred    => false,
                updated_at => gf(unstarred_at, Data)
            },
            project_briefcase_store:put_file(FileId, Updated),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- file_archived_v1: set archived flag, remove from index ---

project(#{event_type := <<"file_archived_v1">>, data := Data},
        _Metadata, State, RM) ->
    FileId = gf(file_id, Data),
    case project_briefcase_store:get_file(FileId) of
        {ok, #{status := S} = File} ->
            _Archived = File#{
                status     => S bor 8,
                updated_at => gf(archived_at, Data)
            },
            project_briefcase_store:delete_file(FileId),
            {ok, State, RM};
        {error, not_found} ->
            {skip, State, RM}
    end;

%% --- Unknown event type: skip ---

project(_Event, _Metadata, State, RM) ->
    {skip, State, RM}.

%% --- Helpers ---

gf(Key, Data) -> hecate_api_utils:get_field(Key, Data).
gf(Key, Data, Default) -> hecate_api_utils:get_field(Key, Data, Default).
