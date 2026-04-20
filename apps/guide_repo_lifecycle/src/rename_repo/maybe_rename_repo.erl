%%% @doc Handler for rename_repo command.
-module(maybe_rename_repo).

-export([handle/1, handle_from_map/1, dispatch/1]).

-include_lib("evoq/include/evoq.hrl").

handle_from_map(Map) ->
    case rename_repo_v1:from_map(Map) of
        {ok, Cmd}        -> handle(Cmd);
        {error, _} = Err -> Err
    end.

handle(Command) ->
    Map = rename_repo_v1:to_map(Command),
    case validate(Map) of
        ok ->
            Event = repo_renamed_v1:new(Map),
            {ok, [repo_renamed_v1:to_map(Event)]};
        {error, _} = Err ->
            Err
    end.

dispatch(Cmd) ->
    RepoId   = rename_repo_v1:get_repo_id(Cmd),
    StreamId = repo_aggregate:stream_id(RepoId),
    CmdMap   = rename_repo_v1:to_map(Cmd),
    EvoqCmd  = #evoq_command{
        command_type   = rename_repo,
        aggregate_type = repo_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => rename_repo},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => repo_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).

validate(#{new_name := N}) when is_binary(N), byte_size(N) > 0 -> ok;
validate(_) -> {error, invalid_new_name}.
