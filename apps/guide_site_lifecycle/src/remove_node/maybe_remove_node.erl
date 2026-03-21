%%% @doc Handler for remove_node command
-module(maybe_remove_node).

-export([handle/1, handle_from_map/1, dispatch/2]).

-dialyzer({nowarn_function, [dispatch/2, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    NodeName = maps:get(node_name, Payload, <<>>),
    RemovedAt = maps:get(removed_at, Payload, erlang:system_time(millisecond)),
    Cmd = remove_node_v1:new(NodeName, RemovedAt),
    handle(Cmd).

-spec handle(remove_node_v1:remove_node_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{node_name := NodeName} =
        remove_node_v1:to_map(Command),
    case byte_size(NodeName) of
        0 -> {error, node_name_required};
        _ ->
            Event = remove_node_v1:to_map(Command),
            {ok, [Event#{event_type => <<"node_removed_v1">>}]}
    end.

-spec dispatch(binary(), remove_node_v1:remove_node_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(SiteId, Cmd) ->
    StreamId = site_aggregate:stream_id(SiteId),
    CmdMap = remove_node_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = remove_node,
        aggregate_type = site_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => remove_node},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => site_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
