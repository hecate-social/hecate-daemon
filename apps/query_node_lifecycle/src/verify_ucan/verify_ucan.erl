%%% @doc Query: verify a UCAN grant by capability ID.
%%%
%%% Checks that the grant exists, is not revoked, and has not expired.
-module(verify_ucan).
-export([get/1]).

-spec get(binary()) -> {ok, map()} | {error, not_found | term()}.
get(CapabilityId) ->
    Sql = "SELECT capability_id, issuer, audience, resource, actions, "
          "expires_at, granted_at, revoked, revoked_at "
          "FROM ucan_grants WHERE capability_id = ?1",
    case query_node_lifecycle_store:query(Sql, [CapabilityId]) of
        {ok, [Row]} ->
            Grant = row_to_map(Row),
            {ok, verify_grant(Grant)};
        {ok, []} ->
            {error, not_found};
        {error, Reason} ->
            {error, Reason}
    end.

verify_grant(#{revoked := true} = Grant) ->
    #{valid => false, grant => Grant, reason => <<"revoked">>};
verify_grant(#{expires_at := ExpiresAt} = Grant) ->
    NowMs = erlang:system_time(millisecond),
    case ExpiresAt > NowMs of
        true ->
            #{valid => true, grant => Grant, reason => undefined};
        false ->
            #{valid => false, grant => Grant, reason => <<"expired">>}
    end.

row_to_map({CapabilityId, Issuer, Audience, Resource, Actions,
            ExpiresAt, GrantedAt, Revoked, RevokedAt}) ->
    #{
        capability_id => CapabilityId,
        issuer => Issuer,
        audience => Audience,
        resource => Resource,
        actions => decode_json(Actions),
        expires_at => ExpiresAt,
        granted_at => GrantedAt,
        revoked => Revoked =:= 1,
        revoked_at => RevokedAt
    };
row_to_map(Row) when is_list(Row) ->
    row_to_map(list_to_tuple(Row)).

decode_json(null) -> null;
decode_json(undefined) -> null;
decode_json(Val) when is_binary(Val) -> json:decode(Val);
decode_json(Val) -> Val.
