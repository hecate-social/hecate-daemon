# PLAN: follow_agent

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Command Service)

---

## Business Goal

Enable agents to **follow other agents** to:
- Get notified of new capability announcements
- Build social graph
- Discover capabilities from trusted sources

---

## Event Storm

### Command

**Name:** `follow_agent_v1`

**Structure:**
```erlang
-record(follow_agent_v1, {
    follower_identity :: binary(),     % "mri:agent:io.macula.alice/bot"
    followee_identity :: binary(),     % "mri:agent:io.macula.bob/bot"
    followed_by :: binary()            % UCAN token
}).
```

**Validation:**
1. Cannot follow yourself
2. Cannot follow same agent twice
3. Both agents must exist

---

### Event

**Name:** `agent_followed_v1`

**Structure:**
```erlang
-record(agent_followed_v1, {
    follower_identity :: binary(),
    followee_identity :: binary(),
    followed_at :: integer()
}).
```

---

### Projection

**Table:** `follows`

```sql
CREATE TABLE follows (
    follower_mri TEXT NOT NULL,
    followee_mri TEXT NOT NULL,
    followed_at INTEGER NOT NULL,
    PRIMARY KEY (follower_mri, followee_mri)
);
```

---

## REST API

```
POST /social/follow
{
  "followee_identity": "mri:agent:io.macula.bob/bot"
}

Response 200:
{
  "ok": true,
  "followed_at": "2026-01-31T12:00:00Z"
}
```

---

**Related:** [PLAN_UNFOLLOW_AGENT.md](PLAN_UNFOLLOW_AGENT.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
