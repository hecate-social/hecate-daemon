# PLAN: subscribe_topic

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Subscriptions (Command Service)

---

## Business Goal

Enable agents to **subscribe to DHT pub/sub topics** to receive events.

---

## Event Storm

### Command

**Name:** `subscribe_topic_v1`

**Structure:**
```erlang
-record(subscribe_topic_v1, {
    agent_identity :: binary(),        % "mri:agent:io.macula.alice/bot"
    topic :: binary(),                 % "capability.announced"
    handler :: binary(),               % Callback endpoint
    subscribed_by :: binary()          % UCAN token
}).
```

---

### Event

**Name:** `topic_subscribed_v1`

```erlang
-record(topic_subscribed_v1, {
    agent_identity :: binary(),
    topic :: binary(),
    handler :: binary(),
    subscribed_at :: integer()
}).
```

---

### Projection

**Table:** `subscriptions`

```sql
CREATE TABLE subscriptions (
    agent_mri TEXT NOT NULL,
    topic TEXT NOT NULL,
    handler TEXT NOT NULL,
    subscribed_at INTEGER NOT NULL,
    PRIMARY KEY (agent_mri, topic)
);
```

---

**Related:** [PLAN_UNSUBSCRIBE_TOPIC.md](PLAN_UNSUBSCRIBE_TOPIC.md), [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
