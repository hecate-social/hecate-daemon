%%% @doc connector_revoked_v1 event
%%% Emitted when a connector is permanently revoked.
-module(connector_revoked_v1).

-export([new/2, to_map/1, from_map/1]).
-export([get_connector_id/1, get_reason/1, get_revoked_at/1]).

-record(connector_revoked_v1, {
    connector_id :: binary(),
    reason       :: binary(),
    revoked_at   :: integer()
}).

-export_type([connector_revoked_v1/0]).
-opaque connector_revoked_v1() :: #connector_revoked_v1{}.

-spec new(binary(), binary()) -> connector_revoked_v1().
new(ConnId, Reason) ->
    #connector_revoked_v1{
        connector_id = ConnId,
        reason = Reason,
        revoked_at = erlang:system_time(millisecond)
    }.

-spec to_map(connector_revoked_v1()) -> map().
to_map(#connector_revoked_v1{} = E) ->
    #{
        event_type => <<"connector_revoked_v1">>,
        connector_id => E#connector_revoked_v1.connector_id,
        reason => E#connector_revoked_v1.reason,
        revoked_at => E#connector_revoked_v1.revoked_at
    }.

-spec from_map(map()) -> {ok, connector_revoked_v1()} | {error, term()}.
from_map(#{connector_id := ConnId, reason := Reason, revoked_at := At}) ->
    {ok, #connector_revoked_v1{
        connector_id = ConnId,
        reason = Reason,
        revoked_at = At
    }};
from_map(_) ->
    {error, invalid_event}.

get_connector_id(#connector_revoked_v1{connector_id = V}) -> V.
get_reason(#connector_revoked_v1{reason = V}) -> V.
get_revoked_at(#connector_revoked_v1{revoked_at = V}) -> V.
