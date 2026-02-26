%%% @doc Convert event records to flat maps for projections.
%%%
%%% Subscribers receive {events, [#evoq_event{}]} from evoq subscriptions.
%%% The event record has business data nested under the `data` field.
%%% Projections need a flat map with both envelope and data fields.
%%%
%%% This module flattens the event: data fields merge at top level,
%%% envelope fields (event_id, event_type, stream_id, version,
%%% timestamp, epoch_us, metadata) are preserved. On collision,
%%% envelope wins.
%%%
%%% Handles both #evoq_event{} (current) and #event{} (legacy).
%%% @end
-module(projection_event).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").
-include_lib("evoq/include/evoq_types.hrl").

-export([to_map/1]).

%% @doc Convert an event record or map to a flat projection map.
%%
%% For #evoq_event{} records: merges data fields at top level with envelope.
%% For #event{} records: same flattening (legacy path).
%% For maps: returns as-is (already flat).
-spec to_map(#evoq_event{} | event() | map()) -> map().
to_map(#evoq_event{} = E) ->
    Envelope = #{
        event_id => E#evoq_event.event_id,
        event_type => E#evoq_event.event_type,
        stream_id => E#evoq_event.stream_id,
        version => E#evoq_event.version,
        metadata => E#evoq_event.metadata,
        timestamp => E#evoq_event.timestamp,
        epoch_us => E#evoq_event.epoch_us
    },
    case E#evoq_event.data of
        Data when is_map(Data) -> maps:merge(Data, Envelope);
        _ -> Envelope
    end;
to_map(#event{} = E) ->
    Envelope = #{
        event_id => E#event.event_id,
        event_type => E#event.event_type,
        stream_id => E#event.stream_id,
        version => E#event.version,
        metadata => E#event.metadata,
        timestamp => E#event.timestamp,
        epoch_us => E#event.epoch_us
    },
    case E#event.data of
        Data when is_map(Data) -> maps:merge(Data, Envelope);
        _ -> Envelope
    end;
to_map(Map) when is_map(Map) ->
    Map.
