# PLAN: unsubscribe_topic

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Subscriptions (Command Service)

---

## Business Goal

Enable agents to **unsubscribe from DHT pub/sub topics**.

---

## Event Storm

### Command

**Name:** `unsubscribe_topic_v1`

**Structure:**
```erlang
-record(unsubscribe_topic_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    unsubscribed_by :: binary()        % UCAN token
}).
```

---

### Event

**Name:** `topic_unsubscribed_v1`

```erlang
-record(topic_unsubscribed_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    unsubscribed_at :: integer()
}).
```

---

### Projection

**Table:** `subscriptions`

```sql
DELETE FROM subscriptions
WHERE agent_mri = ? AND topic = ?;
```

---

**Related:** [PLAN_SUBSCRIBE_TOPIC.md](PLAN_SUBSCRIBE_TOPIC.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
