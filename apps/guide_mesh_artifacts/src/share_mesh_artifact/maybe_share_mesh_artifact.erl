%%% @doc Handler for share_mesh_artifact_v1.
%%%
%%% Calls `hecate_mesh:put_content/1' during handling and embeds the
%%% returned MCID in the produced event. If the content layer is not
%%% available (inproc backend, or pool not yet activated) the command
%%% is rejected with the underlying error — no half-recorded event.
%%% @end
-module(maybe_share_mesh_artifact).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{bytes := Bytes, content_type := ContentType} = Payload)
  when is_binary(Bytes), is_binary(ContentType) ->
    RequestedAt = maps:get(requested_at, Payload, erlang:system_time(millisecond)),
    Cmd = share_mesh_artifact_v1:new(Bytes, ContentType, RequestedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, missing_bytes_or_content_type}.

-spec handle(share_mesh_artifact_v1:share_mesh_artifact_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{bytes := Bytes, content_type := ContentType, requested_at := RequestedAt}
        = share_mesh_artifact_v1:to_map(Command),
    case hecate_mesh:put_content(Bytes) of
        {ok, MCID} ->
            SizeBytes = byte_size(Bytes),
            Event = mesh_artifact_shared_v1:new(MCID, ContentType, SizeBytes, RequestedAt),
            {ok, [mesh_artifact_shared_v1:to_map(Event)]};
        {error, Reason} ->
            {error, Reason}
    end.

-spec dispatch(share_mesh_artifact_v1:share_mesh_artifact_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CmdMap = share_mesh_artifact_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = share_mesh_artifact_v1,
        aggregate_type = mesh_artifacts_aggregate,
        aggregate_id = mesh_artifacts_aggregate:stream_id(),
        payload = CmdMap#{command_type => share_mesh_artifact_v1},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mesh_artifacts_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
