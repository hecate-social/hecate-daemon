# PLAN: update_agent_metadata

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Identities (Command Service)

---

## Business Goal

Update agent metadata (hostname, version, etc.) when it changes.

---

## Event Storm

### Command

**Name:** `update_agent_metadata_v1`

**Structure:**
```erlang
-record(update_agent_metadata_v1, {
    agent_mri :: binary(),
    updates :: map(),                  % New metadata fields
    updated_by :: binary()             % UCAN token
}).
```

**Updates:**
```erlang
#{
    <<"hostname">> => binary(),        % Optional
    <<"version">> => binary(),         % Optional
    <<"last_seen_at">> => integer()    % Heartbeat timestamp
}
```

---

### Event

**Name:** `agent_metadata_updated_v1`

```erlang
-record(agent_metadata_updated_v1, {
    agent_mri :: binary(),
    updates :: map(),
    updated_at :: integer()
}).
```

---

### Projection

**Table:** `agents`

```sql
UPDATE agents
SET hostname = ?,
    version = ?,
    last_seen_at = ?
WHERE agent_mri = ?;
```

---

**Related:** [PLAN_INITIALIZE_AGENT.md](PLAN_INITIALIZE_AGENT.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
