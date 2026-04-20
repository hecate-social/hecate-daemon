%%% @doc archive_repo_v1 command — soft delete.
-module(archive_repo_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1, command_type/0]).
-export([get_repo_id/1, get_reason/1, get_archived_at/1]).

-record(archive_repo_v1, {
    repo_id     :: binary(),
    reason      :: binary(),
    archived_at :: integer()
}).

-opaque archive_repo_v1() :: #archive_repo_v1{}.
-export_type([archive_repo_v1/0]).

command_type() -> archive_repo_v1.

-spec new(map()) -> {ok, archive_repo_v1()} | {error, missing_fields}.
new(#{repo_id := RepoId} = Map) ->
    {ok, #archive_repo_v1{
        repo_id     = RepoId,
        reason      = maps:get(reason,      Map, <<>>),
        archived_at = maps:get(archived_at, Map,
                               erlang:system_time(millisecond))
    }};
new(_) -> {error, missing_fields}.

to_map(#archive_repo_v1{repo_id = Id, reason = R, archived_at = At}) ->
    #{repo_id => Id, reason => R, archived_at => At}.

from_map(Map) -> new(Map).

get_repo_id(#archive_repo_v1{repo_id = V}) -> V.
get_reason(#archive_repo_v1{reason = V}) -> V.
get_archived_at(#archive_repo_v1{archived_at = V}) -> V.
