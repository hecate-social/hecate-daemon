%%% @doc Handler for receive_mesh_fact_v1 command.
%%%
%%% Validates the command shape and produces the matching domain event
%%% (`mesh_fact_received_v1'). No business rules at this layer: the
%%% substrate already validated signatures and dedup'd before delivery.
%%% The handler exists to give the inbound FACT an evoq-anchored audit
%%% trail in `mesh_inbox_store'.
%%% @end
-module(maybe_receive_mesh_fact).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{topic := _, fact := _} = Payload) ->
    case receive_mesh_fact_v1:new(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, _} = E -> E
    end;
handle_from_map(_) ->
    {error, missing_topic_or_fact}.

-spec handle(receive_mesh_fact_v1:receive_mesh_fact_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{topic := T, fact := F, sender_node_id := SN, sender_mri := SM,
      sig_verified := SV, received_at := R}
        = receive_mesh_fact_v1:to_map(Command),
    Event = mesh_fact_received_v1:new(T, F, SN, SM, SV, R),
    {ok, [mesh_fact_received_v1:to_map(Event)]}.

-spec dispatch(receive_mesh_fact_v1:receive_mesh_fact_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CmdMap = receive_mesh_fact_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = receive_mesh_fact_v1,
        aggregate_type = mesh_inbox_aggregate,
        aggregate_id = mesh_inbox_aggregate:stream_id(),
        payload = CmdMap#{command_type => receive_mesh_fact_v1},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mesh_inbox_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
