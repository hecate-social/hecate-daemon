%%% @doc Projection: torch_archived_v1 -> sqlite torches table
%%% Updates torch status with ARCHIVED bit flag in the SQLite read model.
-module(torch_archived_v1_to_sqlite_torches).

-include_lib("manage_torches/include/torch_status.hrl").

-export([project/1]).

%% @doc Project torch_archived_v1 event to torches table.
%% Sets the ARCHIVED bit flag and recomputes status_label.
-spec project(map()) -> ok | {error, term()}.
project(Event) ->
    TorchId = get(torch_id, Event),
    logger:info("[PROJECTION] ~s: projecting archive for ~s", [?MODULE, TorchId]),
    %% 1. Set the ARCHIVED flag
    ok = query_torches_store:execute(
        "UPDATE torches SET status = status | ?1 WHERE torch_id = ?2",
        [?TORCH_ARCHIVED, TorchId]),
    %% 2. Read back new status, recompute label
    case query_torches_store:query(
        "SELECT status FROM torches WHERE torch_id = ?1", [TorchId]) of
        {ok, [{NewStatus}]} ->
            Label = evoq_bit_flags:to_string(NewStatus, ?TORCH_FLAG_MAP),
            query_torches_store:execute(
                "UPDATE torches SET status_label = ?1 WHERE torch_id = ?2",
                [Label, TorchId]);
        _ -> ok
    end.

%% @doc Get value from event map, handling both atom and binary keys.
-spec get(atom(), map()) -> term().
get(Key, Map) when is_atom(Key) ->
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(atom_to_binary(Key, utf8), Map, undefined)
    end.
