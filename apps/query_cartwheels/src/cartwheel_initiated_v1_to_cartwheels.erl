%%% @doc Projection: cartwheel_initiated_v1 -> cartwheels table
-module(cartwheel_initiated_v1_to_cartwheels).

-include_lib("manage_cartwheels/include/cartwheel_status.hrl").

-export([project/1]).

%% @doc Project cartwheel_initiated_v1 event to cartwheels table.
%% Computes and stores status_label at write time.
-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    CartwheelId = get(cartwheel_id, Event),
    ContextName = case get(context_name, Event) of
        undefined -> get(name, Event);
        CN -> CN
    end,
    Status = evoq_bit_flags:set_all(0, [?CW_INITIATED, ?CW_DISCOVERY_ACTIVE]),
    StatusLabel = evoq_bit_flags:to_string(Status, ?CW_FLAG_MAP),
    Sql = "INSERT OR REPLACE INTO cartwheels "
          "(cartwheel_id, torch_id, context_name, description, current_phase, "
          "status, status_label, initiated_at) "
          "VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8)",
    query_cartwheels_store:execute(Sql, [
        CartwheelId,
        get(torch_id, Event),
        ContextName,
        get(description, Event),
        <<"discovery_n_analysis">>,
        Status,
        StatusLabel,
        get(initiated_at, Event, erlang:system_time(millisecond))
    ]).

%% @doc Get value from event map, handling both atom and binary keys.
-spec get(atom(), map()) -> term().
get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.

-spec get(atom(), map(), term()) -> term().
get(Key, Map, Default) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, Default)
    end.
