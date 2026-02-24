%%% @doc pair_node_v1 command
-module(pair_node_v1).

-export([new/3, to_map/1, from_map/1]).

-record(pair_node_v1, {
    github_user :: binary(),
    realm       :: binary(),
    paired_at   :: integer()
}).

-opaque pair_node_v1() :: #pair_node_v1{}.
-export_type([pair_node_v1/0]).

-spec new(binary(), binary(), integer()) -> pair_node_v1().
new(GithubUser, Realm, PairedAt) ->
    #pair_node_v1{
        github_user = GithubUser,
        realm = Realm,
        paired_at = PairedAt
    }.

-spec to_map(pair_node_v1()) -> map().
to_map(#pair_node_v1{
    github_user = GithubUser,
    realm = Realm,
    paired_at = PairedAt
}) ->
    #{
        github_user => GithubUser,
        realm => Realm,
        paired_at => PairedAt
    }.

-spec from_map(map()) -> {ok, pair_node_v1()} | {error, term()}.
from_map(#{github_user := GithubUser, realm := Realm, paired_at := PairedAt}) ->
    {ok, #pair_node_v1{
        github_user = GithubUser,
        realm = Realm,
        paired_at = PairedAt
    }};
from_map(_) ->
    {error, invalid_pair_node_command}.
