%%% @doc connector_suspended_v1 event
%%% Emitted when a connector is temporarily suspended.
-module(connector_suspended_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_connector_id/1, get_reason/1, get_suspended_at/1]).

-record(connector_suspended_v1, {
    connector_id :: binary(),
    reason       :: binary(),
    suspended_at :: integer()
}).

-export_type([connector_suspended_v1/0]).
-opaque connector_suspended_v1() :: #connector_suspended_v1{}.

-spec new(binary(), binary()) -> connector_suspended_v1().
new(ConnId, Reason) ->
    #connector_suspended_v1{
        connector_id = ConnId,
        reason = Reason,
        suspended_at = erlang:system_time(millisecond)
    }.

-spec to_map(connector_suspended_v1()) -> map().
to_map(#connector_suspended_v1{} = E) ->
    #{
        event_type => <<"connector_suspended_v1">>,
        connector_id => E#connector_suspended_v1.connector_id,
        reason => E#connector_suspended_v1.reason,
        suspended_at => E#connector_suspended_v1.suspended_at
    }.

-spec from_map(map()) -> {ok, connector_suspended_v1()} | {error, term()}.
from_map(#{connector_id := ConnId, reason := Reason, suspended_at := At}) ->
    {ok, #connector_suspended_v1{
        connector_id = ConnId,
        reason = Reason,
        suspended_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

get_connector_id(#connector_suspended_v1{connector_id = V}) -> V.
get_reason(#connector_suspended_v1{reason = V}) -> V.
get_suspended_at(#connector_suspended_v1{suspended_at = V}) -> V.
