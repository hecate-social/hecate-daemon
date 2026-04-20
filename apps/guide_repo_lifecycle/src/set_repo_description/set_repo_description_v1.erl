%%% @doc set_repo_description_v1 command.
-module(set_repo_description_v1).
-behaviour(evoq_command).

-export([new/1, to_map/1, from_map/1, command_type/0]).
-export([get_repo_id/1, get_description/1, get_set_at/1]).

-record(set_repo_description_v1, {
    repo_id     :: binary(),
    description :: binary(),
    set_at      :: integer()
}).

-opaque set_repo_description_v1() :: #set_repo_description_v1{}.
-export_type([set_repo_description_v1/0]).

command_type() -> set_repo_description_v1.

new(#{repo_id := RepoId, description := Desc} = Map) ->
    {ok, #set_repo_description_v1{
        repo_id     = RepoId,
        description = Desc,
        set_at      = maps:get(set_at, Map,
                               erlang:system_time(millisecond))
    }};
new(_) -> {error, missing_fields}.

to_map(#set_repo_description_v1{repo_id = Id, description = D, set_at = At}) ->
    #{repo_id => Id, description => D, set_at => At}.

from_map(Map) -> new(Map).

get_repo_id(#set_repo_description_v1{repo_id = V}) -> V.
get_description(#set_repo_description_v1{description = V}) -> V.
get_set_at(#set_repo_description_v1{set_at = V}) -> V.
