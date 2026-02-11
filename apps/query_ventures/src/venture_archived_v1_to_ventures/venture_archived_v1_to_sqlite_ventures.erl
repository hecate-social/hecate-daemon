%%% @doc Projection: venture_archived_v1 -> sqlite ventures table
-module(venture_archived_v1_to_sqlite_ventures).

-include_lib("setup_venture/include/venture_status.hrl").

-export([project/1]).

%% @doc Project venture_archived_v1 event to ventures table.
%% Sets the ARCHIVED bit flag and recomputes status_label.
-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    VentureId = get(venture_id, Event),
    logger:info("[PROJECTION] ~s: projecting archive for ~s", [?MODULE, VentureId]),
    %% 1. Set the ARCHIVED flag
    ok = query_ventures_store:execute(
        "UPDATE ventures SET status = status | ?1 WHERE venture_id = ?2",
        [?VENTURE_ARCHIVED, VentureId]),
    %% 2. Read back new status, recompute label
    case query_ventures_store:query(
        "SELECT status FROM ventures WHERE venture_id = ?1", [VentureId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?VENTURE_FLAG_MAP),
            query_ventures_store:execute(
                "UPDATE ventures SET status_label = ?1 WHERE venture_id = ?2",
                [Label, VentureId]);
        {ok, [[NewStatus]]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?VENTURE_FLAG_MAP),
            query_ventures_store:execute(
                "UPDATE ventures SET status_label = ?1 WHERE venture_id = ?2",
                [Label, VentureId]);
        _ -> ok
    end.

%% @doc Get value from event map, handling both atom and binary keys.
-spec get(atom(), map()) -> term().
get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
