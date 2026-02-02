# PLAN: grant_capability (UCAN)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** UCAN (Command Service)

---

## Business Goal

Issue UCAN tokens granting capabilities (permissions) to other agents.

**Use Case:** Alice grants Bob permission to announce capabilities on her behalf.

---

## Event Storm

### Command

**Name:** `grant_capability_v1`

**Structure:**
```erlang
-record(grant_capability_v1, {
    issuer_identity :: binary(),       % "mri:agent:io.macula.alice/bot"
    grantee_identity :: binary(),      % "mri:agent:io.macula.bob/bot"
    capability :: binary(),            % "announce_capability"
    scope :: binary(),                 % "mri:realm:io.macula.alice/*"
    expires_at :: integer() | undefined, % Optional expiry
    granted_by :: binary()             % UCAN token (self-signed by issuer)
}).
```

**Capabilities:**
- `announce_capability` - Can announce capabilities
- `update_capability` - Can update capabilities
- `moderate_disputes` - Can resolve disputes
- `admin` - Full control

---

### Event

**Name:** `capability_granted_v1`

```erlang
-record(capability_granted_v1, {
    token_id :: binary(),              % UUID v7
    issuer_identity :: binary(),
    grantee_identity :: binary(),
    capability :: binary(),
    scope :: binary(),
    expires_at :: integer() | undefined,
    granted_at :: integer()
}).
```

---

### Projection

**Table:** `ucan_capabilities`

```sql
CREATE TABLE ucan_capabilities (
    token_id TEXT PRIMARY KEY,
    issuer_mri TEXT NOT NULL,
    grantee_mri TEXT NOT NULL,
    capability TEXT NOT NULL,
    scope TEXT NOT NULL,
    expires_at INTEGER,
    granted_at INTEGER NOT NULL,
    revoked_at INTEGER
);
```

---

**Related:** [PLAN_REVOKE_UCAN_CAPABILITY.md](PLAN_REVOKE_UCAN_CAPABILITY.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
