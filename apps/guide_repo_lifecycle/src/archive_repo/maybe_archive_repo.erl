%%% @doc Handler for archive_repo command.
-module(maybe_archive_repo).

-export([handle/1, handle_from_map/1, dispatch/1]).

-include_lib("evoq/include/evoq.hrl").

handle_from_map(Map) ->
    case archive_repo_v1:from_map(Map) of
        {ok, Cmd}        -> handle(Cmd);
        {error, _} = Err -> Err
    end.

handle(Command) ->
    Map = archive_repo_v1:to_map(Command),
    Event = repo_archived_v1:new(Map),
    {ok, [repo_archived_v1:to_map(Event)]}.

dispatch(Cmd) ->
    RepoId   = archive_repo_v1:get_repo_id(Cmd),
    StreamId = repo_aggregate:stream_id(RepoId),
    CmdMap   = archive_repo_v1:to_map(Cmd),
    EvoqCmd  = #evoq_command{
        command_type   = archive_repo,
        aggregate_type = repo_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => archive_repo},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => repo_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
