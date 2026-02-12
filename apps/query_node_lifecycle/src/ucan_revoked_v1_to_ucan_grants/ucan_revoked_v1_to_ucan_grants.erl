%%% @doc Projects ucan_revoked_v1 events into the ucan_grants table.
-module(ucan_revoked_v1_to_ucan_grants).
-export([project/1]).

project(Data) when is_map(Data) ->
    CapabilityId = get_field(capability_id, Data),
    RevokedAt = get_field(revoked_at, Data),

    Sql = "UPDATE ucan_grants SET revoked = 1, revoked_at = ? "
          "WHERE capability_id = ?",
    Params = [RevokedAt, CapabilityId],
    query_node_lifecycle_store:execute(Sql, Params);
project(_) -> ok.

%% ===================================================================
%% Internal
%% ===================================================================

get_field(Key, Map) when is_atom(Key) ->
    BinKey = atom_to_binary(Key),
    case maps:find(Key, Map) of
        {ok, V} -> V;
        error -> maps:get(BinKey, Map, undefined)
    end.
