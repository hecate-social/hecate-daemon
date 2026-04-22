%%% @doc Handler for complete_file_download_v1.
%%%
%%% Dispatched by `briefcase_download_worker` on successful cache
%%% write. Emits `file_download_completed_v1`. The aggregate gates
%%% this command on `FILE_DOWNLOADING` — if it's not set something
%%% went wrong and we reject (either the download wasn't started via
%%% start_file_download, or a cancel raced ahead).
%%% @end
-module(maybe_complete_file_download).

-export([handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{file_id := FileId,
                  source_realm := Realm,
                  cache_size := Size,
                  frames := Frames} = Payload) ->
    CompletedAt = maps:get(completed_at, Payload,
                           erlang:system_time(millisecond)),
    {ok, Event} = file_download_completed_v1:new(#{
        file_id      => FileId,
        source_realm => Realm,
        cache_size   => Size,
        frames       => Frames,
        completed_at => CompletedAt}),
    {ok, [file_download_completed_v1:to_map(Event)]};
handle_from_map(_) ->
    {error, missing_fields}.

-spec dispatch(complete_file_download_v1:complete_file_download_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId   = complete_file_download_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    Payload  = complete_file_download_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = complete_file_download_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = Payload#{command_type => complete_file_download_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).
