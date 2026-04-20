%%% @doc Handler for set_repo_description command.
-module(maybe_set_repo_description).

-export([handle/1, handle_from_map/1, dispatch/1]).

-include_lib("evoq/include/evoq.hrl").

handle_from_map(Map) ->
    case set_repo_description_v1:from_map(Map) of
        {ok, Cmd}        -> handle(Cmd);
        {error, _} = Err -> Err
    end.

handle(Command) ->
    Map   = set_repo_description_v1:to_map(Command),
    Event = repo_description_set_v1:new(Map),
    {ok, [repo_description_set_v1:to_map(Event)]}.

dispatch(Cmd) ->
    RepoId   = set_repo_description_v1:get_repo_id(Cmd),
    StreamId = repo_aggregate:stream_id(RepoId),
    CmdMap   = set_repo_description_v1:to_map(Cmd),
    EvoqCmd  = #evoq_command{
        command_type   = set_repo_description,
        aggregate_type = repo_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => set_repo_description},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => repo_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
