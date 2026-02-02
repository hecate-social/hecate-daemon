# PLAN: verify_capability (UCAN Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** UCAN (Query Service)

---

## Business Goal

Verify if a UCAN token is valid and grants a specific capability.

---

## Query

### Query Command

**Name:** `verify_capability_v1`

**Structure:**
```erlang
-record(verify_capability_v1, {
    token_id :: binary(),              % UCAN token ID
    required_capability :: binary(),   % e.g., "announce_capability"
    required_scope :: binary()         % e.g., "mri:realm:io.macula.alice/*"
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#verify_capability_v1{token_id = TokenId, required_capability = ReqCap, required_scope = ReqScope}) ->
    SQL = <<"
        SELECT token_id, capability, scope, expires_at, revoked_at
        FROM ucan_capabilities
        WHERE token_id = ?
    ">>,

    case hecate_store:query_one(SQL, [TokenId]) of
        {ok, Row} ->
            verify_token(Row, ReqCap, ReqScope);
        {error, not_found} ->
            {error, invalid_token}
    end.

verify_token(#{capability := Cap, scope := Scope, expires_at := Expires, revoked_at := Revoked}, ReqCap, ReqScope) ->
    Now = erlang:system_time(millisecond),
    Checks = [
        {Cap =:= ReqCap, <<"Capability mismatch">>},
        {scope_matches(Scope, ReqScope), <<"Scope mismatch">>},
        {Revoked =:= undefined, <<"Token revoked">>},
        {Expires =:= undefined orelse Expires > Now, <<"Token expired">>}
    ],
    case lists:all(fun({Check, _}) -> Check end, Checks) of
        true -> {ok, valid};
        false -> {error, lists:keyfind(false, 1, Checks)}
    end.
```

---

## REST API

```
POST /ucan/verify
{
  "token_id": "...",
  "required_capability": "announce_capability",
  "required_scope": "mri:realm:io.macula.alice/*"
}

Response 200:
{
  "valid": true
}

Response 403:
{
  "valid": false,
  "reason": "Token revoked"
}
```

---

**Related:** [PLAN_LIST_UCAN_CAPABILITIES.md](PLAN_LIST_UCAN_CAPABILITIES.md), [PLAN_GRANT_UCAN_CAPABILITY.md](PLAN_GRANT_UCAN_CAPABILITY.md)
