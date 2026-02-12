%%% @doc Projects capability_endorsed_v1 events into the endorsements table.
-module(capability_endorsed_v1_to_endorsements).
-export([project/1]).

project(Data) when is_map(Data) ->
    EndorserIdentity = get_field(endorser_identity, Data),
    CapMri = get_field(capability_mri, Data),
    Comment = get_field(comment, Data),
    EndorsedAt = get_field(endorsed_at, Data),

    Sql = "INSERT OR REPLACE INTO endorsements "
          "(endorser_identity, capability_mri, comment, endorsed_at) "
          "VALUES (?, ?, ?, ?)",
    Params = [EndorserIdentity, CapMri, Comment, EndorsedAt],
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
