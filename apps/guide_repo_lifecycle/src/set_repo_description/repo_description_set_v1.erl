%%% @doc repo_description_set_v1 event.
-module(repo_description_set_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1, event_type/0]).

-record(repo_description_set_v1, {
    repo_id     :: binary(),
    description :: binary(),
    set_at      :: integer()
}).

-opaque repo_description_set_v1() :: #repo_description_set_v1{}.
-export_type([repo_description_set_v1/0]).

event_type() -> <<"repo_description_set_v1">>.

new(#{repo_id := RepoId, description := Desc, set_at := At}) ->
    #repo_description_set_v1{repo_id = RepoId, description = Desc, set_at = At}.

to_map(#repo_description_set_v1{repo_id = Id, description = D, set_at = At}) ->
    #{event_type => <<"repo_description_set_v1">>,
      repo_id => Id, description => D, set_at => At}.

from_map(#{repo_id := _, description := _, set_at := _} = Map) ->
    {ok, new(Map)};
from_map(_) -> {error, invalid_repo_description_set_event}.
