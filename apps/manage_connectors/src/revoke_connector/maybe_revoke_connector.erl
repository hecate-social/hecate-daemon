%%% @doc maybe_revoke_connector handler
%%% Business logic for revoking connectors.
-module(maybe_revoke_connector).

-include_lib("evoq/include/evoq.hrl").

-export([handle/1, dispatch/1]).


-spec handle(revoke_connector_v1:revoke_connector_v1()) ->
    {ok, [connector_revoked_v1:connector_revoked_v1()]} | {error, term()}.
handle(Cmd) ->
    ConnId = revoke_connector_v1:get_connector_id(Cmd),
    Reason = revoke_connector_v1:get_reason(Cmd),
    Event = connector_revoked_v1:new(ConnId, Reason),
    {ok, [Event]}.

-spec dispatch(revoke_connector_v1:revoke_connector_v1()) ->
    {ok, non_neg_integer(), [map()]} | {error, term()}.
dispatch(Cmd) ->
    ConnId = revoke_connector_v1:get_connector_id(Cmd),
    Timestamp = erlang:system_time(millisecond),

    EvoqCmd = #evoq_command{
        command_type = revoke_connector,
        aggregate_type = connector_aggregate,
        aggregate_id = <<"connector-", ConnId/binary>>,
        payload = revoke_connector_v1:to_map(Cmd),
        metadata = #{timestamp => Timestamp, aggregate_type => connector_aggregate},
        causation_id = undefined,
        correlation_id = undefined
    },

    Opts = #{
        store_id => manage_connectors_store,
        adapter => reckon_evoq_adapter,
        consistency => eventual
    },

    evoq_dispatcher:dispatch(EvoqCmd, Opts).
