%%% @doc Handler for unpair_node command
-module(maybe_unpair_node).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1]}).
-dialyzer({nowarn_function, [handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(Payload) ->
    Reason = maps:get(reason, Payload, <<"manual">>),
    UnpairedAt = maps:get(unpaired_at, Payload, erlang:system_time(millisecond)),
    Cmd = unpair_node_v1:new(Reason, UnpairedAt),
    handle(Cmd).

-spec handle(unpair_node_v1:unpair_node_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{reason := Reason, unpaired_at := UnpairedAt} = unpair_node_v1:to_map(Command),
    Event = node_unpaired_v1:new(Reason, UnpairedAt),
    {ok, [node_unpaired_v1:to_map(Event)]}.

-spec dispatch(unpair_node_v1:unpair_node_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    StreamId = settings_aggregate:stream_id(),
    CmdMap = unpair_node_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = unpair_node,
        aggregate_type = settings_aggregate,
        aggregate_id = StreamId,
        payload = CmdMap#{command_type => unpair_node},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => hecate_event_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
