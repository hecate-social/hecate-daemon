# PLAN: get_subscription_stats (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Subscriptions (Query Service)

---

## Business Goal

Get subscription statistics (total subs, messages received, etc.).

---

## Query

### Query Command

**Name:** `get_subscription_stats_v1`

**Structure:**
```erlang
-record(get_subscription_stats_v1, {
    agent_identity :: binary()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_subscription_stats_v1{agent_identity = AgentMri}) ->
    SQL = <<"
        SELECT COUNT(*) as total_subscriptions
        FROM subscriptions
        WHERE agent_mri = ?
    ">>,

    {ok, [{Total}]} = hecate_store:query(SQL, [AgentMri]),
    {ok, #{<<"total_subscriptions">> => Total}}.
```

---

## REST API

```
GET /subscriptions/stats

Response 200:
{
  "total_subscriptions": 5,
  "messages_received_today": 127
}
```

---

**Related:** [PLAN_LIST_SUBSCRIPTIONS.md](PLAN_LIST_SUBSCRIPTIONS.md)
