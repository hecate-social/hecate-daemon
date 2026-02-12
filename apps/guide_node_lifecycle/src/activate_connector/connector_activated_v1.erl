%%% @doc connector_activated_v1 event
%%% Emitted when a suspended connector is re-activated.
-module(connector_activated_v1).

-export([new/1, to_map/1, from_map/1]).
-export([get_connector_id/1, get_activated_at/1]).

-record(connector_activated_v1, {
    connector_id :: binary(),
    activated_at :: integer()
}).

-export_type([connector_activated_v1/0]).
-opaque connector_activated_v1() :: #connector_activated_v1{}.

-spec new(binary()) -> connector_activated_v1().
new(ConnId) ->
    #connector_activated_v1{
        connector_id = ConnId,
        activated_at = erlang:system_time(millisecond)
    }.

-spec to_map(connector_activated_v1()) -> map().
to_map(#connector_activated_v1{connector_id = ConnId, activated_at = At}) ->
    #{
        event_type => <<"connector_activated_v1">>,
        connector_id => ConnId,
        activated_at => At
    }.

-spec from_map(map()) -> {ok, connector_activated_v1()} | {error, term()}.
from_map(#{connector_id := ConnId, activated_at := At}) ->
    {ok, #connector_activated_v1{connector_id = ConnId, activated_at = At}};
from_map(_) ->
    {error, invalid_event}.

get_connector_id(#connector_activated_v1{connector_id = V}) -> V.
get_activated_at(#connector_activated_v1{activated_at = V}) -> V.
