%%% @doc Handler for disconnect_node command.
-module(maybe_disconnect_node).
-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-include_lib("evoq/include/evoq.hrl").

handle(Command) ->
    #{source_node := Source, target_node := Target} = disconnect_node_v1:to_map(Command),
    case Source =/= Target of
        true ->
            Event = node_disconnected_v1:new(Source, Target, erlang:system_time(millisecond)),
            {ok, [node_disconnected_v1:to_map(Event)]};
        false ->
            {error, cannot_disconnect_self}
    end.

handle_from_map(Payload) ->
    Source = maps:get(source_node, Payload, maps:get(<<"source_node">>, Payload, <<>>)),
    Target = maps:get(target_node, Payload, maps:get(<<"target_node">>, Payload, <<>>)),
    Cmd = disconnect_node_v1:new(Source, Target),
    handle(Cmd).

dispatch(Cmd) ->
    #{source_node := SourceNode} = disconnect_node_v1:to_map(Cmd),
    Timestamp = erlang:system_time(millisecond),
    CmdMap = disconnect_node_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = disconnect_node,
        aggregate_type = node_aggregate,
        aggregate_id = SourceNode,
        payload = CmdMap#{command_type => disconnect_node},
        metadata = #{timestamp => Timestamp}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
