# PLAN: get_agent (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Identities (Query Service)

---

## Business Goal

Get detailed information about a specific agent.

---

## Query

### Query Command

**Name:** `get_agent_v1`

**Structure:**
```erlang
-record(get_agent_v1, {
    agent_identity :: binary()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_agent_v1{agent_identity = AgentMri}) ->
    SQL = <<"
        SELECT agent_mri, public_key, org_identity,
               hostname, os, version, initialized_at, last_seen_at
        FROM agents
        WHERE agent_mri = ?
    ">>,

    case hecate_store:query_one(SQL, [AgentMri]) of
        {ok, Row} -> {ok, row_to_agent(Row)};
        {error, not_found} -> {error, not_found}
    end.
```

---

## REST API

```
GET /agents/:agent_mri

Response 200:
{
  "agent_mri": "mri:agent:io.macula.alice/bot",
  "org_identity": "mri:org:io.macula.alice",
  "hostname": "macbook-pro.local",
  "os": "unix/darwin",
  "version": "0.1.0",
  "initialized_at": "...",
  "last_seen_at": "..."
}
```

---

**Related:** [PLAN_LIST_AGENTS.md](PLAN_LIST_AGENTS.md), [PLAN_INITIALIZE_AGENT.md](PLAN_INITIALIZE_AGENT.md)
