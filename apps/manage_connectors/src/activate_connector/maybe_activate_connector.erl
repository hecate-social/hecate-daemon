%%% @doc maybe_activate_connector handler
%%% Business logic for activating connectors.
-module(maybe_activate_connector).

-export([handle/1]).

-spec handle(activate_connector_v1:activate_connector_v1()) ->
    {ok, [connector_activated_v1:connector_activated_v1()]} | {error, term()}.
handle(Cmd) ->
    ConnId = activate_connector_v1:get_connector_id(Cmd),
    Event = connector_activated_v1:new(ConnId),
    {ok, [Event]}.
