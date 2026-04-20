%%% @doc rename_repo_v1 command.
-module(rename_repo_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1, command_type/0]).
-export([get_repo_id/1, get_new_name/1, get_renamed_at/1]).

-record(rename_repo_v1, {
    repo_id    :: binary(),
    new_name   :: binary(),
    renamed_at :: integer()
}).

-opaque rename_repo_v1() :: #rename_repo_v1{}.
-export_type([rename_repo_v1/0]).

command_type() -> rename_repo_v1.

new(#{repo_id := RepoId, new_name := Name} = Map) ->
    {ok, #rename_repo_v1{
        repo_id    = RepoId,
        new_name   = Name,
        renamed_at = maps:get(renamed_at, Map,
                              erlang:system_time(millisecond))
    }};
new(_) -> {error, missing_fields}.

to_map(#rename_repo_v1{repo_id = Id, new_name = N, renamed_at = At}) ->
    #{repo_id => Id, new_name => N, renamed_at => At}.

from_map(Map) -> new(Map).

get_repo_id(#rename_repo_v1{repo_id = V}) -> V.
get_new_name(#rename_repo_v1{new_name = V}) -> V.
get_renamed_at(#rename_repo_v1{renamed_at = V}) -> V.
