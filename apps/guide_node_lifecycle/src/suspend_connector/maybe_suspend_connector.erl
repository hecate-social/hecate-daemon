%%% @doc maybe_suspend_connector handler
%%% Business logic for suspending connectors.
-module(maybe_suspend_connector).

-export([handle/1, handle_from_map/1]).

%% @doc Handle suspend_connector from a plain map payload.
-spec handle_from_map(map()) -> {ok, [connector_suspended_v1:connector_suspended_v1()]} | {error, term()}.
handle_from_map(#{connector_id := _ConnId} = Payload) ->
    case suspend_connector_v1:new(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, Reason} -> {error, Reason}
    end.

-spec handle(suspend_connector_v1:suspend_connector_v1()) ->
    {ok, [connector_suspended_v1:connector_suspended_v1()]} | {error, term()}.
handle(Cmd) ->
    ConnId = suspend_connector_v1:get_connector_id(Cmd),
    Reason = suspend_connector_v1:get_reason(Cmd),
    Event = connector_suspended_v1:new(ConnId, Reason),
    {ok, [Event]}.
