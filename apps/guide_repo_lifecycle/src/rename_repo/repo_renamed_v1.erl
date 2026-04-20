%%% @doc repo_renamed_v1 event.
-module(repo_renamed_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1, event_type/0]).

-record(repo_renamed_v1, {
    repo_id    :: binary(),
    new_name   :: binary(),
    renamed_at :: integer()
}).

-opaque repo_renamed_v1() :: #repo_renamed_v1{}.
-export_type([repo_renamed_v1/0]).

event_type() -> <<"repo_renamed_v1">>.

new(#{repo_id := RepoId, new_name := Name, renamed_at := At}) ->
    #repo_renamed_v1{repo_id = RepoId, new_name = Name, renamed_at = At}.

to_map(#repo_renamed_v1{repo_id = Id, new_name = N, renamed_at = At}) ->
    #{event_type => <<"repo_renamed_v1">>,
      repo_id => Id, new_name => N, renamed_at => At}.

from_map(#{repo_id := _, new_name := _, renamed_at := _} = Map) ->
    {ok, new(Map)};
from_map(_) -> {error, invalid_repo_renamed_event}.
