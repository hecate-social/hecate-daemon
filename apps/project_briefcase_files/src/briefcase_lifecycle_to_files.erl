%%% @doc Merged projection: briefcase lifecycle events -> files ETS.
%%%
%%% Phase 1 handles `file_uploaded_v1` only. Later phases add
%%% `file_revised_v1`, `file_moved_v1`, `file_archived_v1`,
%%% `file_purged_v1`, `folder_opened_v1`, `folder_collapsed_v1`,
%%% `access_granted_v1`, `access_revoked_v1`, chunk transfer events.
%%% @end
-module(briefcase_lifecycle_to_files).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

-define(TABLE, briefcase_files).

interested_in() ->
    [<<"file_uploaded_v1">>].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case get_event_type(Event) of
        <<"file_uploaded_v1">> -> project_file_uploaded(Data, State, RM);
        _                      -> {ok, State, RM}
    end.

%% ===================================================================
%% file_uploaded_v1 — insert new file into read model
%% ===================================================================

project_file_uploaded(Data, State, RM) ->
    FileId = gf(file_id, Data),
    Entry = #{
        file_id      => FileId,
        realm        => gf(realm, Data),
        path         => gf(path, Data),
        mime_type    => gf(mime_type, Data),
        size         => gf(size, Data),
        content_hash => gf(content_hash, Data),
        author_did   => gf(author_did, Data),
        uploaded_at  => gf(uploaded_at, Data),
        status       => 1,
        status_label => <<"Uploaded">>
    },
    {ok, RM2} = evoq_read_model:put(RM, FileId, Entry),
    {ok, State, RM2}.

%% ===================================================================
%% Helpers
%% ===================================================================

get_event_type(#{event_type := T}) -> T;
get_event_type(#{<<"event_type">> := T}) -> T;
get_event_type(_) -> undefined.

gf(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, undefined)
    end.
