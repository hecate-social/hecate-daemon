# PLAN: list_rpc_calls (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Reputation (Query Service)

---

## Business Goal

List RPC call history for an agent (caller or provider), paginated.

---

## Query

### Query Command

**Name:** `list_rpc_calls_v1`

**Structure:**
```erlang
-record(list_rpc_calls_v1, {
    agent_identity :: binary(),        % Filter by this agent (as caller OR provider)
    limit :: integer(),                % Default: 20
    offset :: integer()                % Default: 0
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#list_rpc_calls_v1{agent_identity = AgentMri, limit = Limit, offset = Offset}) ->
    SQL = <<"
        SELECT call_id, caller_identity, provider_identity, capability_mri,
               procedure_name, call_result, response_time_ms, tracked_at
        FROM rpc_calls
        WHERE caller_identity = ? OR provider_identity = ?
        ORDER BY tracked_at DESC
        LIMIT ? OFFSET ?
    ">>,

    {ok, Rows} = hecate_store:query(SQL, [AgentMri, AgentMri, Limit, Offset]),
    {ok, [row_to_rpc_call(R) || R <- Rows]}.
```

---

## REST API

```
GET /reputation/:agent_mri/calls?limit=50

Response 200:
{
  "calls": [...],
  "total": 1247,
  "limit": 50,
  "offset": 0
}
```

---

**Related:** [PLAN_GET_REPUTATION.md](PLAN_GET_REPUTATION.md), [PLAN_TRACK_RPC_CALL.md](PLAN_TRACK_RPC_CALL.md)
