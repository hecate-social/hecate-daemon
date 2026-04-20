%%% @doc repo_initiated_v1 event.
%%%
%%% Emitted when a repo is first initiated on a Hecate node.
%%% @end
-module(repo_initiated_v1).
-behaviour(evoq_event).

-export([new/1, to_map/1, from_map/1]).
-export([event_type/0]).

-record(repo_initiated_v1, {
    repo_id        :: binary(),
    realm          :: binary(),
    name           :: binary(),
    owner_did      :: binary(),
    description    :: binary(),
    default_branch :: binary(),
    visibility     :: binary(),
    tags           :: [binary()],
    initiated_at   :: integer()
}).

-opaque repo_initiated_v1() :: #repo_initiated_v1{}.
-export_type([repo_initiated_v1/0]).

event_type() -> <<"repo_initiated_v1">>.

-spec new(map()) -> repo_initiated_v1().
new(#{repo_id := RepoId, realm := Realm, name := Name,
      owner_did := Did, description := Desc, default_branch := Branch,
      visibility := Vis, tags := Tags, initiated_at := At}) ->
    #repo_initiated_v1{
        repo_id = RepoId, realm = Realm, name = Name, owner_did = Did,
        description = Desc, default_branch = Branch, visibility = Vis,
        tags = Tags, initiated_at = At
    }.

-spec to_map(repo_initiated_v1()) -> map().
to_map(#repo_initiated_v1{
    repo_id = RepoId, realm = Realm, name = Name, owner_did = Did,
    description = Desc, default_branch = Branch, visibility = Vis,
    tags = Tags, initiated_at = At}) ->
    #{
        event_type     => <<"repo_initiated_v1">>,
        repo_id        => RepoId,
        realm          => Realm,
        name           => Name,
        owner_did      => Did,
        description    => Desc,
        default_branch => Branch,
        visibility     => Vis,
        tags           => Tags,
        initiated_at   => At
    }.

-spec from_map(map()) -> {ok, repo_initiated_v1()} | {error, term()}.
from_map(#{repo_id := _} = Map) -> {ok, new(Map)};
from_map(_) -> {error, invalid_repo_initiated_event}.
