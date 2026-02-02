# PLAN: get_reputation (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Reputation (Query Service)

---

## Business Goal

Retrieve reputation score and stats for an agent.

---

## Query

### Query Command

**Name:** `get_reputation_v1`

**Structure:**
```erlang
-record(get_reputation_v1, {
    agent_identity :: binary()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_reputation_v1{agent_identity = AgentMri}) ->
    SQL = <<"
        SELECT agent_mri, reputation_score, total_calls,
               success_rate, avg_response_time_ms, last_updated
        FROM agent_reputation
        WHERE agent_mri = ?
    ">>,

    case hecate_store:query_one(SQL, [AgentMri]) of
        {ok, Row} -> {ok, row_to_reputation(Row)};
        {error, not_found} -> {ok, default_reputation(AgentMri)}
    end.
```

---

## REST API

```
GET /reputation/:agent_mri

Response 200:
{
  "agent_identity": "mri:agent:io.macula.alice/bot",
  "reputation_score": 98,
  "total_calls": 1247,
  "success_rate": 0.98,
  "avg_response_time_ms": 234,
  "last_updated": "2026-01-31T12:00:00Z"
}
```

---

**Related:** [PLAN_TRACK_RPC_CALL.md](PLAN_TRACK_RPC_CALL.md), [PLAN_LIST_RPC_CALLS.md](PLAN_LIST_RPC_CALLS.md)
