%%% @doc Handler for fail_file_download_v1.
-module(maybe_fail_file_download).

-export([handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

handle_from_map(#{file_id := FileId} = Payload) ->
    FailedAt = maps:get(failed_at, Payload, erlang:system_time(millisecond)),
    {ok, Event} = file_download_failed_v1:new(#{
        file_id       => FileId,
        reason        => maps:get(reason, Payload, unknown),
        partial_bytes => maps:get(partial_bytes, Payload, 0),
        failed_at     => FailedAt}),
    {ok, [file_download_failed_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

dispatch(Cmd) ->
    FileId   = fail_file_download_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    Payload  = fail_file_download_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = fail_file_download_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => fail_file_download_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
