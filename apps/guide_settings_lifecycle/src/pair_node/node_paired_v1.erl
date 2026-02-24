%%% @doc node_paired_v1 event
-module(node_paired_v1).

-export([new/3, to_map/1, from_map/1]).

-record(node_paired_v1, {
    github_user :: binary(),
    realm       :: binary(),
    paired_at   :: integer()
}).

-opaque node_paired_v1() :: #node_paired_v1{}.
-export_type([node_paired_v1/0]).

-spec new(binary(), binary(), integer()) -> node_paired_v1().
new(GithubUser, Realm, PairedAt) ->
    #node_paired_v1{
        github_user = GithubUser,
        realm = Realm,
        paired_at = PairedAt
    }.

-spec to_map(node_paired_v1()) -> map().
to_map(#node_paired_v1{
    github_user = GithubUser,
    realm = Realm,
    paired_at = PairedAt
}) ->
    #{
        event_type => <<"node_paired_v1">>,
        github_user => GithubUser,
        realm => Realm,
        paired_at => PairedAt
    }.

-spec from_map(map()) -> {ok, node_paired_v1()} | {error, term()}.
from_map(#{github_user := GithubUser, realm := Realm, paired_at := PairedAt}) ->
    {ok, #node_paired_v1{
        github_user = GithubUser,
        realm = Realm,
        paired_at = PairedAt
    }};
from_map(_) ->
    {error, invalid_node_paired_event}.
