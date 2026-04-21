%%% @doc Handler for share_file command.
%%%
%%% Validates the file exists in the aggregate state (must have
%%% `FILE_UPLOADED` set, must not already have `FILE_SHARED`). Emits
%%% `file_shared_v1` domain event. No mesh emission in Phase A — that
%%% lands in Phase B.
%%% @end
-module(maybe_share_file).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{file_id := FileId} = Payload) ->
    SharedAt = maps:get(shared_at, Payload,
                        erlang:system_time(millisecond)),
    Cmd = share_file_v1:new(FileId, SharedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(share_file_v1:share_file_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    Map = share_file_v1:to_map(Command),
    case validate(Map) of
        ok ->
            #{file_id := FileId, shared_at := SharedAt} = Map,
            Event = file_shared_v1:new(FileId, SharedAt),
            {ok, [file_shared_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(share_file_v1:share_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId = share_file_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    CmdMap = share_file_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = share_file_v1,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => share_file_v1},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).

%% Internal

validate(#{file_id := FileId}) when is_binary(FileId), byte_size(FileId) > 0 ->
    ok;
validate(_) ->
    {error, file_id_required}.
