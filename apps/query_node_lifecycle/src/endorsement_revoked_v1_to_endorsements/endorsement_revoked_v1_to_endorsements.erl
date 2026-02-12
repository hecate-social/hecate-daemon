%%% @doc Projects endorsement_revoked_v1 events into the endorsements table.
-module(endorsement_revoked_v1_to_endorsements).
-export([project/1]).

project(Data) when is_map(Data) ->
    EndorserIdentity = get_field(endorser_identity, Data),
    CapMri = get_field(capability_mri, Data),
    RevokedAt = get_field(revoked_at, Data),

    Sql = "UPDATE endorsements SET revoked_at = ? "
          "WHERE endorser_identity = ? AND capability_mri = ?",
    Params = [RevokedAt, EndorserIdentity, CapMri],
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
