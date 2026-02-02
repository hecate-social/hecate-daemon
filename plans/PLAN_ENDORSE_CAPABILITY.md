# PLAN: endorse_capability

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Command Service)

---

## Business Goal

Enable agents to **endorse capabilities** they've used and found valuable. Endorsements:
- Build trust
- Improve discoverability
- Influence reputation

---

## Event Storm

### Command

**Name:** `endorse_capability_v1`

**Structure:**
```erlang
-record(endorse_capability_v1, {
    capability_mri :: binary(),        % "mri:capability:io.macula.bob/weather"
    endorser_identity :: binary(),     % "mri:agent:io.macula.alice/bot"
    comment :: binary() | undefined,   % Optional: "Best weather service!"
    endorsed_by :: binary()            % UCAN token
}).
```

**Validation:**
1. Capability must exist and not be retracted
2. Cannot endorse your own capability
3. Cannot endorse same capability twice
4. Comment max 500 characters

---

### Event

**Name:** `capability_endorsed_v1`

**Structure:**
```erlang
-record(capability_endorsed_v1, {
    capability_mri :: binary(),
    endorser_identity :: binary(),
    comment :: binary() | undefined,
    endorsed_at :: integer()
}).
```

---

### Projection

**Table:** `endorsements`

```sql
CREATE TABLE endorsements (
    capability_mri TEXT NOT NULL,
    endorser_mri TEXT NOT NULL,
    comment TEXT,
    endorsed_at INTEGER NOT NULL,
    PRIMARY KEY (capability_mri, endorser_mri)
);
```

---

## REST API

```
POST /social/endorse
{
  "capability_mri": "mri:capability:io.macula.bob/weather",
  "comment": "Best weather service on the mesh!"
}

Response 200:
{
  "ok": true,
  "endorsed_at": "2026-01-31T12:00:00Z"
}
```

---

**Related:** [PLAN_REVOKE_ENDORSEMENT.md](PLAN_REVOKE_ENDORSEMENT.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
