%%% @doc Merged projection: repo lifecycle events -> repos ETS.
%%%
%%% Phase 1 handles all four lifecycle events emitted by
%%% `guide_repo_lifecycle`: initiated, renamed, description_set, archived.
%%% @end
-module(repo_lifecycle_to_repos).
-behaviour(evoq_projection).

-export([interested_in/0, init/1, project/4]).

-define(TABLE, repos).

interested_in() ->
    [
        <<"repo_initiated_v1">>,
        <<"repo_renamed_v1">>,
        <<"repo_description_set_v1">>,
        <<"repo_archived_v1">>
    ].

init(_Config) ->
    {ok, RM} = evoq_read_model:new(evoq_read_model_ets, #{name => ?TABLE}),
    {ok, #{}, RM}.

project(#{data := Data} = Event, _Metadata, State, RM) ->
    case event_type(Event) of
        <<"repo_initiated_v1">>       -> project_initiated(Data, State, RM);
        <<"repo_renamed_v1">>         -> project_renamed(Data, State, RM);
        <<"repo_description_set_v1">> -> project_description_set(Data, State, RM);
        <<"repo_archived_v1">>        -> project_archived(Data, State, RM);
        _                              -> {ok, State, RM}
    end.

%% ===================================================================
%% Event handlers
%% ===================================================================

project_initiated(Data, State, RM) ->
    RepoId = gf(repo_id, Data),
    Entry  = #{
        repo_id        => RepoId,
        realm          => gf(realm,          Data),
        name           => gf(name,           Data),
        owner_did      => gf(owner_did,      Data),
        description    => gf(description,    Data, <<>>),
        default_branch => gf(default_branch, Data, <<"main">>),
        visibility     => gf(visibility,     Data, <<"private">>),
        tags           => gf(tags,           Data, []),
        status         => <<"active">>,
        initiated_at   => gf(initiated_at,   Data),
        revised_at     => undefined,
        archived_at    => undefined
    },
    {ok, RM2} = evoq_read_model:put(RepoId, Entry, RM),
    {ok, State, RM2}.

project_renamed(Data, State, RM) ->
    RepoId = gf(repo_id, Data),
    update_entry(RepoId, State, RM, fun(Entry) ->
        Entry#{
            name       := gf(new_name, Data),
            revised_at := gf(renamed_at, Data)
        }
    end).

project_description_set(Data, State, RM) ->
    RepoId = gf(repo_id, Data),
    update_entry(RepoId, State, RM, fun(Entry) ->
        Entry#{
            description := gf(description, Data),
            revised_at  := gf(set_at, Data)
        }
    end).

project_archived(Data, State, RM) ->
    RepoId = gf(repo_id, Data),
    update_entry(RepoId, State, RM, fun(Entry) ->
        Entry#{
            status      := <<"archived">>,
            archived_at := gf(archived_at, Data)
        }
    end).

%% ===================================================================
%% Helpers
%% ===================================================================

update_entry(RepoId, State, RM, UpdateFun) ->
    case evoq_read_model:get(RepoId, RM) of
        {ok, Entry} ->
            {ok, RM2} = evoq_read_model:put(RepoId, UpdateFun(Entry), RM),
            {ok, State, RM2};
        {error, not_found} ->
            {ok, State, RM}
    end.

event_type(#{event_type := T}) -> T;
event_type(#{<<"event_type">> := T}) -> T;
event_type(_) -> undefined.

gf(Key, Map)          -> gf(Key, Map, undefined).
gf(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
