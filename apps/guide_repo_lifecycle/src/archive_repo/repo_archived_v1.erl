%%% @doc repo_archived_v1 event — soft delete fact.
-module(repo_archived_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1, event_type/0]).

-record(repo_archived_v1, {
    repo_id     :: binary(),
    reason      :: binary(),
    archived_at :: integer()
}).

-opaque repo_archived_v1() :: #repo_archived_v1{}.
-export_type([repo_archived_v1/0]).

event_type() -> <<"repo_archived_v1">>.

new(#{repo_id := RepoId, reason := Reason, archived_at := At}) ->
    #repo_archived_v1{repo_id = RepoId, reason = Reason, archived_at = At}.

to_map(#repo_archived_v1{repo_id = Id, reason = R, archived_at = At}) ->
    #{event_type => <<"repo_archived_v1">>,
      repo_id => Id, reason => R, archived_at => At}.

from_map(#{repo_id := _, reason := _, archived_at := _} = Map) ->
    {ok, new(Map)};
from_map(_) -> {error, invalid_repo_archived_event}.
