%%% @doc Handler for add_mesh_subscription_v1 command.
%%%
%%% Validates the command shape and produces the matching domain event
%%% (`mesh_subscription_added_v1'). Idempotency (no-op when already
%%% subscribed) is enforced one layer up, in
%%% `mesh_subscriptions_aggregate:execute/2'.
%%% @end
-module(maybe_add_mesh_subscription).

-export([handle/1, handle_from_map/1, dispatch/1]).

-dialyzer({nowarn_function, [dispatch/1, handle/1]}).

-include_lib("evoq/include/evoq.hrl").

-spec handle_from_map(map()) -> {ok, [map()]} | {error, term()}.
handle_from_map(#{topic := Topic} = Payload) when is_binary(Topic) ->
    RequestedAt = maps:get(requested_at, Payload, erlang:system_time(millisecond)),
    Cmd = add_mesh_subscription_v1:new(Topic, RequestedAt),
    handle(Cmd);
handle_from_map(_) ->
    {error, missing_topic}.

-spec handle(add_mesh_subscription_v1:add_mesh_subscription_v1()) ->
    {ok, [map()]} | {error, term()}.
handle(Command) ->
    #{topic := Topic, requested_at := RequestedAt}
        = add_mesh_subscription_v1:to_map(Command),
    Event = mesh_subscription_added_v1:new(Topic, RequestedAt),
    {ok, [mesh_subscription_added_v1:to_map(Event)]}.

-spec dispatch(add_mesh_subscription_v1:add_mesh_subscription_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    CmdMap = add_mesh_subscription_v1:to_map(Cmd),
    EvoqCmd = #evoq_command{
        command_type = add_mesh_subscription_v1,
        aggregate_type = mesh_subscriptions_aggregate,
        aggregate_id = mesh_subscriptions_aggregate:stream_id(),
        payload = CmdMap#{command_type => add_mesh_subscription_v1},
        metadata = #{timestamp => erlang:system_time(millisecond)}
    },
    evoq_dispatcher:dispatch(EvoqCmd, #{
        store_id => mesh_subscriptions_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    }).
