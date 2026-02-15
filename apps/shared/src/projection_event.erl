%%% @doc Convert ReckonDB #event{} records to flat maps for projections.
%%%
%%% ReckonDB emitters send {events, [#event{}]} to subscribers.
%%% The #event{} record has business data nested under the `data` field.
%%% Projections need a flat map with both envelope and data fields.
%%%
%%% This module flattens the event: data fields merge at top level,
%%% envelope fields (event_id, event_type, stream_id, version,
%%% timestamp, epoch_us, metadata) are preserved. On collision,
%%% envelope wins.
%%%
%%% NOTE: evoq has evoq_event_store:event_to_map/1 for #evoq_event{}
%%% records but it is not yet exported. This module handles the
%%% reckon_gater #event{} record directly.
%%% @end
-module(projection_event).

-include_lib("reckon_gater/include/esdb_gater_types.hrl").

-export([to_map/1]).

%% @doc Convert an #event{} record or map to a flat projection map.
%%
%% For #event{} records: merges data fields at top level with envelope.
%% For maps: returns as-is (already flat).
-spec to_map(event() | map()) -> map().
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
