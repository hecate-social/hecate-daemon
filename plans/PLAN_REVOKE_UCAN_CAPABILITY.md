# PLAN: revoke_capability (UCAN)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** UCAN (Command Service)

---

## Business Goal

Revoke previously granted UCAN capabilities.

**Use Case:** Alice revokes Bob's permission to announce capabilities after abuse.

---

## Event Storm

### Command

**Name:** `revoke_capability_v1`

**Structure:**
```erlang
-record(revoke_capability_v1, {
    token_id :: binary(),              % UUID v7 of token to revoke
    issuer_identity :: binary(),       % Only issuer can revoke
    reason :: binary() | undefined,    % Optional
    revoked_by :: binary()             % UCAN token
}).
```

---

### Event

**Name:** `capability_revoked_v1`

```erlang
-record(capability_revoked_v1, {
    token_id :: binary(),
    issuer_identity :: binary(),
    reason :: binary() | undefined,
    revoked_at :: integer()
}).
```

---

### Projection

**Table:** `ucan_capabilities`

```sql
UPDATE ucan_capabilities
SET revoked_at = ?
WHERE token_id = ? AND issuer_mri = ?;
```

---

**Related:** [PLAN_GRANT_UCAN_CAPABILITY.md](PLAN_GRANT_UCAN_CAPABILITY.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
