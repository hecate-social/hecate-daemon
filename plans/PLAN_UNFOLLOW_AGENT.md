# PLAN: unfollow_agent

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Command Service)

---

## Business Goal

Enable agents to **unfollow other agents**.

---

## Event Storm

### Command

**Name:** `unfollow_agent_v1`

**Structure:**
```erlang
-record(unfollow_agent_v1, {
    follower_identity :: binary(),
    followee_identity :: binary(),
    unfollowed_by :: binary()          % UCAN token
}).
```

**Validation:**
1. Must be currently following
2. Cannot unfollow yourself (can't follow yourself anyway)

---

### Event

**Name:** `agent_unfollowed_v1`

**Structure:**
```erlang
-record(agent_unfollowed_v1, {
    follower_identity :: binary(),
    followee_identity :: binary(),
    unfollowed_at :: integer()
}).
```

---

### Projection

**Table:** `follows`

```sql
DELETE FROM follows
WHERE follower_mri = ? AND followee_mri = ?;
```

---

## REST API

```
DELETE /social/follow/:followee_mri

Response 200:
{
  "ok": true,
  "unfollowed_at": "2026-01-31T12:00:00Z"
}
```

---

**Related:** [PLAN_FOLLOW_AGENT.md](PLAN_FOLLOW_AGENT.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
