%%% @doc Handler for upload_file command.
%%%
%%% Validates payload, emits `file_uploaded_v1`. Chunk storage +
%%% mesh emission are added in Phase 2+.
%%% @end
-module(maybe_upload_file).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{file_id := FileId, realm := Realm, path := Path,
                  mime_type := Mime, size := Size, content_hash := Hash,
                  author_did := Did} = Payload) ->
    UploadedAt = maps:get(uploaded_at, Payload,
                          erlang:system_time(millisecond)),
    Cmd = upload_file_v1:new(FileId, Realm, Path, Mime, Size, Hash,
                             Did, UploadedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, missing_fields}.

-spec handle(upload_file_v1:upload_file_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    Map = upload_file_v1:to_map(Command),
    case validate(Map) of
        ok ->
            #{file_id := FileId, realm := Realm, path := Path,
              mime_type := Mime, size := Size, content_hash := Hash,
              author_did := Did, uploaded_at := UploadedAt} = Map,
            Event = file_uploaded_v1:new(FileId, Realm, Path, Mime,
                                         Size, Hash, Did, UploadedAt),
            {ok, [file_uploaded_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(upload_file_v1:upload_file_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    FileId = upload_file_v1:get_file_id(Cmd),
    StreamId = briefcase_aggregate:stream_id(FileId),
    CmdMap = upload_file_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type   = upload_file,
        aggregate_type = briefcase_aggregate,
        aggregate_id   = StreamId,
        payload        = CmdMap#{command_type => upload_file},
        metadata       = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id    => briefcase_store,
        adapter     => reckon_evoq_adapter,
        consistency => eventual
    }).

%% Internal

validate(#{realm := R, path := P, content_hash := H, author_did := D, size := Sz}) ->
    case {byte_size(R), byte_size(P), byte_size(H), byte_size(D), Sz} of
        {0, _, _, _, _} -> {error, realm_required};
        {_, 0, _, _, _} -> {error, path_required};
        {_, _, 0, _, _} -> {error, content_hash_required};
        {_, _, _, 0, _} -> {error, author_did_required};
        {_, _, _, _, S} when S < 0 -> {error, invalid_size};
        _ -> ok
    end;
validate(_) ->
    {error, missing_fields}.
