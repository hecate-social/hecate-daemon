%%% @doc maybe_activate_connector handler
%%% Business logic for activating connectors.
-module(maybe_activate_connector).

-export([handle/1, handle_from_map/1]).

%% @doc Handle activate_connector from a plain map payload.
-spec handle_from_map(map()) -> {ok, [connector_activated_v1:connector_activated_v1()]} | {error, term()}.
handle_from_map(#{connector_id := _ConnId} = Payload) ->
    case activate_connector_v1:new(Payload) of
        {ok, Cmd} -> handle(Cmd);
        {error, Reason} -> {error, Reason}
    end.

-spec handle(activate_connector_v1:activate_connector_v1()) ->
    {ok, [connector_activated_v1:connector_activated_v1()]} | {error, term()}.
handle(Cmd) ->
    ConnId = activate_connector_v1:get_connector_id(Cmd),
    Event = connector_activated_v1:new(ConnId),
    {ok, [Event]}.
