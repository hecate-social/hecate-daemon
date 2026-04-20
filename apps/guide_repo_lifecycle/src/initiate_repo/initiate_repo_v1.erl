%%% @doc initiate_repo_v1 command.
%%%
%%% First appearance of a repo on a Hecate node. Creates the bare git
%%% store on disk (Phase 2) and publishes its MRI to the realm catalog.
%%% @end
-module(initiate_repo_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1]).
-export([command_type/0]).
-export([get_repo_id/1, get_realm/1, get_name/1, get_owner_did/1,
         get_description/1, get_default_branch/1, get_visibility/1,
         get_tags/1, get_initiated_at/1]).

-record(initiate_repo_v1, {
    repo_id        :: binary(),
    realm          :: binary(),
    name           :: binary(),
    owner_did      :: binary(),
    description    :: binary(),
    default_branch :: binary(),
    visibility     :: binary(),     %% <<"public">> | <<"private">>
    tags           :: [binary()],
    initiated_at   :: integer()
}).

-opaque initiate_repo_v1() :: #initiate_repo_v1{}.
-export_type([initiate_repo_v1/0]).

command_type() -> initiate_repo_v1.

-spec new(map()) -> {ok, initiate_repo_v1()} | {error, missing_fields}.
new(#{repo_id := RepoId, realm := Realm, name := Name,
      owner_did := Did} = Map) ->
    {ok, #initiate_repo_v1{
        repo_id        = RepoId,
        realm          = Realm,
        name           = Name,
        owner_did      = Did,
        description    = maps:get(description,    Map, <<>>),
        default_branch = maps:get(default_branch, Map, <<"main">>),
        visibility     = maps:get(visibility,     Map, <<"private">>),
        tags           = maps:get(tags,           Map, []),
        initiated_at   = maps:get(initiated_at,   Map,
                                  erlang:system_time(millisecond))
    }};
new(_) ->
    {error, missing_fields}.

-spec to_map(initiate_repo_v1()) -> map().
to_map(#initiate_repo_v1{
    repo_id = RepoId, realm = Realm, name = Name, owner_did = Did,
    description = Desc, default_branch = Branch, visibility = Vis,
    tags = Tags, initiated_at = At}) ->
    #{
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

-spec from_map(map()) -> {ok, initiate_repo_v1()} | {error, term()}.
from_map(Map) -> new(Map).

get_repo_id(#initiate_repo_v1{repo_id = V}) -> V.
get_realm(#initiate_repo_v1{realm = V}) -> V.
get_name(#initiate_repo_v1{name = V}) -> V.
get_owner_did(#initiate_repo_v1{owner_did = V}) -> V.
get_description(#initiate_repo_v1{description = V}) -> V.
get_default_branch(#initiate_repo_v1{default_branch = V}) -> V.
get_visibility(#initiate_repo_v1{visibility = V}) -> V.
get_tags(#initiate_repo_v1{tags = V}) -> V.
get_initiated_at(#initiate_repo_v1{initiated_at = V}) -> V.
