# PLAN: list_agents (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Identities (Query Service)

---

## Business Goal

List all agents, optionally filtered by organization or realm.

---

## Query

### Query Command

**Name:** `list_agents_v1`

**Structure:**
```erlang
-record(list_agents_v1, {
    filters :: map(),
    limit :: integer(),
    offset :: integer()
}).
```

**Filters:**
```erlang
#{
    <<"org_identity">> => binary(),    % Filter by organization
    <<"realm">> => binary()            % Filter by realm
}
```

---

### Handler

**Pseudocode:**
```erlang
handle(#list_agents_v1{filters = Filters, limit = Limit, offset = Offset}) ->
    {SQL, Params} = build_agents_query(Filters, Limit, Offset),
    {ok, Rows} = hecate_store:query(SQL, Params),
    {ok, [row_to_agent(R) || R <- Rows]}.
```

---

## REST API

```
GET /agents?org_identity=mri:org:io.macula.alice

Response 200:
{
  "agents": [...],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

---

**Related:** [PLAN_GET_AGENT.md](PLAN_GET_AGENT.md), [PLAN_INITIALIZE_AGENT.md](PLAN_INITIALIZE_AGENT.md)
