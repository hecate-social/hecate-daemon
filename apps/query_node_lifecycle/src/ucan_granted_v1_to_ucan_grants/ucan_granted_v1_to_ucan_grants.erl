%%% @doc Projects ucan_granted_v1 events into the ucan_grants table.
-module(ucan_granted_v1_to_ucan_grants).
-export([project/1]).

project(Data) when is_map(Data) ->
    CapabilityId = get_field(capability_id, Data),
    Issuer = get_field(issuer, Data),
    Audience = get_field(audience, Data),
    Resource = get_field(resource, Data),
    RawActions = get_field(actions, Data),
    Actions = encode_json_list(RawActions),
    ExpiresAt = get_field(expires_at, Data),
    GrantedAt = get_field(granted_at, Data),

    Sql = "INSERT OR REPLACE INTO ucan_grants "
          "(capability_id, issuer, audience, resource, actions, expires_at, granted_at) "
          "VALUES (?, ?, ?, ?, ?, ?, ?)",
    Params = [CapabilityId, Issuer, Audience, Resource, Actions, ExpiresAt, GrantedAt],
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

encode_json_list(undefined) -> <<"[]">>;
encode_json_list(Val) when is_list(Val) -> json:encode(Val);
encode_json_list(Val) when is_binary(Val) -> Val;
encode_json_list(_) -> <<"[]">>.
