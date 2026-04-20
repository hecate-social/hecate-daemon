%%% @doc State module for repo aggregate.
%%%
%%% Owns the state record, event folding, and serialization. One
%%% aggregate instance per repo — stream id is `repo-{repo_id}`.
%%% @end
-module(repo_state).

-behaviour(evoq_state).

-include("repo_state.hrl").
-include("repo_status.hrl").

-export([new/1, apply_event/2, to_map/1]).

-type state() :: #repo_state{}.
-export_type([state/0]).

%% @doc Create initial empty state for a given aggregate id (repo_id).
-spec new(binary()) -> state().
new(RepoId) ->
    #repo_state{
        repo_id = RepoId,
        tags    = [],
        status  = 0
    }.

%% @doc Apply event to state. State FIRST, Event SECOND.
-spec apply_event(state(), map()) -> state().
apply_event(State, #{event_type := EventType} = Event) ->
    do_apply(EventType, State, Event);
apply_event(State, _) ->
    State.

%% @doc Serialize state to map.
-spec to_map(state()) -> map().
to_map(#repo_state{} = S) ->
    #{
        repo_id        => S#repo_state.repo_id,
        realm          => S#repo_state.realm,
        name           => S#repo_state.name,
        owner_did      => S#repo_state.owner_did,
        description    => S#repo_state.description,
        default_branch => S#repo_state.default_branch,
        tags           => S#repo_state.tags,
        status         => S#repo_state.status,
        initiated_at   => S#repo_state.initiated_at,
        revised_at     => S#repo_state.revised_at,
        archived_at    => S#repo_state.archived_at
    }.

%% ===================================================================
%% Event folding
%% ===================================================================

do_apply(<<"repo_initiated_v1">>, State, #{data := Data}) ->
    apply_repo_initiated(State, Data);
do_apply(<<"repo_initiated_v1">>, State, Data) ->
    apply_repo_initiated(State, Data);

do_apply(<<"repo_renamed_v1">>, State, #{data := Data}) ->
    apply_repo_renamed(State, Data);
do_apply(<<"repo_renamed_v1">>, State, Data) ->
    apply_repo_renamed(State, Data);

do_apply(<<"repo_description_set_v1">>, State, #{data := Data}) ->
    apply_repo_description_set(State, Data);
do_apply(<<"repo_description_set_v1">>, State, Data) ->
    apply_repo_description_set(State, Data);

do_apply(<<"repo_archived_v1">>, State, #{data := Data}) ->
    apply_repo_archived(State, Data);
do_apply(<<"repo_archived_v1">>, State, Data) ->
    apply_repo_archived(State, Data);

do_apply(_Unknown, State, _Event) ->
    State.

apply_repo_initiated(State, Data) ->
    Visibility = gf(visibility, Data, <<"private">>),
    Status0 = evoq_bit_flags:set(State#repo_state.status, ?REPO_INITIATED),
    Status1 = case Visibility of
        <<"public">> -> evoq_bit_flags:set(Status0, ?REPO_PUBLIC);
        _            -> Status0
    end,
    State#repo_state{
        realm          = gf(realm,          Data),
        name           = gf(name,           Data),
        owner_did      = gf(owner_did,      Data),
        description    = gf(description,    Data, <<>>),
        default_branch = gf(default_branch, Data, <<"main">>),
        tags           = gf(tags,           Data, []),
        initiated_at   = gf(initiated_at,   Data),
        status         = Status1
    }.

apply_repo_renamed(State, Data) ->
    State#repo_state{
        name       = gf(new_name, Data),
        revised_at = gf(renamed_at, Data),
        status     = evoq_bit_flags:set(State#repo_state.status, ?REPO_RENAMED)
    }.

apply_repo_description_set(State, Data) ->
    State#repo_state{
        description = gf(description, Data),
        revised_at  = gf(set_at, Data),
        status      = evoq_bit_flags:set(State#repo_state.status, ?REPO_DESCRIPTION_SET)
    }.

apply_repo_archived(State, Data) ->
    State#repo_state{
        archived_at = gf(archived_at, Data),
        status      = evoq_bit_flags:set(State#repo_state.status, ?REPO_ARCHIVED)
    }.

%% Field accessor with default — handles both atom and binary keys.
gf(Key, Map)          -> gf(Key, Map, undefined).
gf(Key, Map, Default) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error   ->
            BinKey = atom_to_binary(Key, utf8),
            maps:get(BinKey, Map, Default)
    end.
