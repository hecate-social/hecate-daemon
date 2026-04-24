%%% @doc Handler for admit_node command
-module(maybe_admit_node).

-export([handle/1, handle_from_map/1, dispatch/2, dispatch_with_retry/2]).

-dialyzer({nowarn_function, [dispatch/2, dispatch_with_retry/2, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    NodeName = maps:get(node_name, Payload, <<>>),
    AdmittedAt = maps:get(admitted_at, Payload, erlang:system_time(millisecond)),
    Cmd = admit_node_v1:new(NodeName, AdmittedAt),
    handle(Cmd).

-spec handle(admit_node_v1:admit_node_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{node_name := NodeName} =
        admit_node_v1:to_map(Command),
    case byte_size(NodeName) of
        0 -> {error, node_name_required};
        _ ->
            Event = admit_node_v1:to_map(Command),
            {ok, [Event#{event_type => <<"node_admitted_v1">>}]}
    end.

-spec dispatch(binary(), admit_node_v1:admit_node_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(SiteId, Cmd) ->
    StreamId = site_aggregate:stream_id(SiteId),
    CmdMap = admit_node_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = admit_node,
        aggregate_type = site_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => admit_node},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => site_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).

%% @doc Dispatch with retry for the boot-time race where admit_node
%% fires before the site aggregate has replayed its
%% `site_initiated_v1` event. Retries on `not_initiated` and
%% `{wrong_expected_version,_,_}` with 500ms backoff, up to 10
%% attempts (~5s window).
-spec dispatch_with_retry(binary(), admit_node_v1:admit_node_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch_with_retry(SiteId, Cmd) ->
    dispatch_with_retry(SiteId, Cmd, 10).

dispatch_with_retry(SiteId, Cmd, 0) ->
    dispatch(SiteId, Cmd);
dispatch_with_retry(SiteId, Cmd, Retries) ->
    case dispatch(SiteId, Cmd) of
        {error, not_initiated} ->
            timer:sleep(500),
            dispatch_with_retry(SiteId, Cmd, Retries - 1);
        {error, {wrong_expected_version, _, _}} ->
            timer:sleep(500),
            dispatch_with_retry(SiteId, Cmd, Retries - 1);
        Other ->
            Other
    end.
