%%% @doc Aggregate for repo lifecycle.
%%%
%%% One aggregate per repo. Stream: `repo-{repo_id}`.
%%% repo_id is a UUIDv7 generated at initiation time (time-sortable).
%%% @end
-module(repo_aggregate).
-behaviour(evoq_aggregate).

-include("repo_state.hrl").
-include("repo_status.hrl").

-export([init/1, execute/2, apply/2]).
-export([state_module/0, stream_id/1]).

-spec state_module() -> module().
state_module() -> repo_state.

%% ===================================================================
%% Evoq callbacks
%% ===================================================================

init(AggregateId) ->
    {ok, repo_state:new(AggregateId)}.

-spec stream_id(binary()) -> binary().
stream_id(RepoId) when is_binary(RepoId) ->
    <<"repo-", RepoId/binary>>.

execute(State, #{command_type := CmdType} = Payload) ->
    do_execute(CmdType, State, Payload);
execute(_State, _Unknown) ->
    {error, unknown_command}.

apply(State, Event) ->
    repo_state:apply_event(State, Event).

%% ===================================================================
%% Command routing
%% ===================================================================

do_execute(initiate_repo, State, Payload) ->
    case evoq_bit_flags:has(State#repo_state.status, ?REPO_INITIATED) of
        true  -> {error, already_initiated};
        false -> maybe_initiate_repo:handle_from_map(Payload)
    end;

do_execute(archive_repo, State, Payload) ->
    case {evoq_bit_flags:has(State#repo_state.status, ?REPO_INITIATED),
          evoq_bit_flags:has(State#repo_state.status, ?REPO_ARCHIVED)} of
        {false, _}     -> {error, not_initiated};
        {true,  true}  -> {error, already_archived};
        {true,  false} -> maybe_archive_repo:handle_from_map(Payload)
    end;

do_execute(rename_repo, State, Payload) ->
    guard_live(State, fun() -> maybe_rename_repo:handle_from_map(Payload) end);

do_execute(set_repo_description, State, Payload) ->
    guard_live(State, fun() -> maybe_set_repo_description:handle_from_map(Payload) end);

do_execute(_Unknown, _State, _Payload) ->
    {error, unknown_command}.

guard_live(State, Fun) ->
    case {evoq_bit_flags:has(State#repo_state.status, ?REPO_INITIATED),
          evoq_bit_flags:has(State#repo_state.status, ?REPO_ARCHIVED)} of
        {false, _}    -> {error, not_initiated};
        {true, true}  -> {error, archived};
        {true, false} -> Fun()
    end.
