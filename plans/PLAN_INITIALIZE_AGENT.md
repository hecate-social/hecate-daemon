# PLAN: initialize_agent

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Identities (Command Service)

---

## Business Goal

Create agent identity when hecate first starts. This is the **bootstrap event** that creates the agent's record in the network.

---

## Event Storm

### Command

**Name:** `initialize_agent_v1`

**Structure:**
```erlang
-record(initialize_agent_v1, {
    agent_mri :: binary(),             % "mri:agent:io.macula.alice/hecate-abc123"
    public_key :: binary(),            % Ed25519 public key
    agent_info :: map(),               % Hostname, OS, version
    org_identity :: binary(),          % "mri:org:io.macula.alice"
    initialized_by :: binary()         % Self-signed UCAN
}).
```

**Agent Info:**
```erlang
#{
    <<"hostname">> => binary(),
    <<"os">> => binary(),
    <<"version">> => binary()
}
```

---

### Event

**Name:** `agent_initialized_v1`

```erlang
-record(agent_initialized_v1, {
    agent_mri :: binary(),
    public_key :: binary(),
    agent_info :: map(),
    org_identity :: binary(),
    initialized_at :: integer()
}).
```

---

### Projection

**Table:** `agents`

```sql
CREATE TABLE agents (
    agent_mri TEXT PRIMARY KEY,
    public_key BLOB NOT NULL,
    org_identity TEXT NOT NULL,
    hostname TEXT,
    os TEXT,
    version TEXT,
    initialized_at INTEGER NOT NULL,
    last_seen_at INTEGER
);
```

---

**Related:** [PLAN_UPDATE_AGENT_METADATA.md](PLAN_UPDATE_AGENT_METADATA.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
