# PLAN: revoke_endorsement

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Command Service)

---

## Business Goal

Enable agents to **revoke previous endorsements** if:
- Capability quality degraded
- Service became unreliable
- Changed opinion

---

## Event Storm

### Command

**Name:** `revoke_endorsement_v1`

**Structure:**
```erlang
-record(revoke_endorsement_v1, {
    capability_mri :: binary(),
    endorser_identity :: binary(),
    reason :: binary() | undefined,    % Optional: "Service became unreliable"
    revoked_by :: binary()             % UCAN token
}).
```

**Validation:**
1. Must have previously endorsed this capability
2. Cannot revoke non-existent endorsement

---

### Event

**Name:** `endorsement_revoked_v1`

**Structure:**
```erlang
-record(endorsement_revoked_v1, {
    capability_mri :: binary(),
    endorser_identity :: binary(),
    reason :: binary() | undefined,
    revoked_at :: integer()
}).
```

---

### Projection

**Table:** `endorsements`

```sql
DELETE FROM endorsements
WHERE capability_mri = ? AND endorser_mri = ?;
```

---

## REST API

```
DELETE /social/endorse/:capability_mri

{
  "reason": "Service became unreliable"
}

Response 200:
{
  "ok": true,
  "revoked_at": "2026-01-31T12:00:00Z"
}
```

---

**Related:** [PLAN_ENDORSE_CAPABILITY.md](PLAN_ENDORSE_CAPABILITY.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
