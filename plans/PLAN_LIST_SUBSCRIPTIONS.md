# PLAN: list_subscriptions (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Subscriptions (Query Service)

---

## Business Goal

List all active subscriptions for an agent.

---

## Query

### Query Command

**Name:** `list_subscriptions_v1`

**Structure:**
```erlang
-record(list_subscriptions_v1, {
    agent_identity :: binary()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#list_subscriptions_v1{agent_identity = AgentMri}) ->
    SQL = <<"
        SELECT topic, handler, subscribed_at
        FROM subscriptions
        WHERE agent_mri = ?
        ORDER BY subscribed_at DESC
    ">>,

    {ok, Rows} = hecate_store:query(SQL, [AgentMri]),
    {ok, [row_to_subscription(R) || R <- Rows]}.
```

---

## REST API

```
GET /subscriptions

Response 200:
{
  "subscriptions": [
    {
      "topic": "capability.announced",
      "handler": "http://localhost:5000/events",
      "subscribed_at": "..."
    },
    ...
  ]
}
```

---

**Related:** [PLAN_SUBSCRIBE_TOPIC.md](PLAN_SUBSCRIBE_TOPIC.md), [PLAN_GET_SUBSCRIPTION_STATS.md](PLAN_GET_SUBSCRIPTION_STATS.md)
