# PLAN: list_capabilities (UCAN Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** UCAN (Query Service)

---

## Business Goal

List UCAN capabilities granted by or to an agent.

---

## Query

### Query Command

**Name:** `list_capabilities_v1`

**Structure:**
```erlang
-record(list_capabilities_v1, {
    agent_identity :: binary(),        % List tokens involving this agent
    role :: atom(),                    % issuer | grantee | both
    include_revoked :: boolean()       % Default: false
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#list_capabilities_v1{agent_identity = AgentMri, role = Role, include_revoked = IncludeRevoked}) ->
    SQL = build_ucan_list_query(AgentMri, Role, IncludeRevoked),
    {ok, Rows} = hecate_store:query(SQL, [AgentMri]),
    {ok, [row_to_ucan_capability(R) || R <- Rows]}.
```

---

## REST API

```
GET /ucan/capabilities?role=issuer

Response 200:
{
  "capabilities": [
    {
      "token_id": "...",
      "grantee": "mri:agent:io.macula.bob/bot",
      "capability": "announce_capability",
      "scope": "mri:realm:io.macula.alice/*",
      "granted_at": "...",
      "revoked_at": null
    },
    ...
  ]
}
```

---

**Related:** [PLAN_VERIFY_UCAN_CAPABILITY.md](PLAN_VERIFY_UCAN_CAPABILITY.md), [PLAN_GRANT_UCAN_CAPABILITY.md](PLAN_GRANT_UCAN_CAPABILITY.md)
