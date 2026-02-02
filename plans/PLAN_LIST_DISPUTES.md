# PLAN: list_disputes (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Reputation (Query Service)

---

## Business Goal

List disputes, optionally filtered by status or agent.

---

## Query

### Query Command

**Name:** `list_disputes_v1`

**Structure:**
```erlang
-record(list_disputes_v1, {
    filters :: map(),                  % Optional
    limit :: integer(),
    offset :: integer()
}).
```

**Filters:**
```erlang
#{
    <<"status">> => atom(),            % pending | resolved | dismissed
    <<"agent_identity">> => binary()   % Disputes involving this agent
}
```

---

### Handler

**Pseudocode:**
```erlang
handle(#list_disputes_v1{filters = Filters, limit = Limit, offset = Offset}) ->
    {SQL, Params} = build_dispute_query(Filters, Limit, Offset),
    {ok, Rows} = hecate_store:query(SQL, Params),
    {ok, [row_to_dispute(R) || R <- Rows]}.
```

---

## REST API

```
GET /disputes?status=pending

Response 200:
{
  "disputes": [...],
  "total": 5,
  "limit": 20,
  "offset": 0
}
```

---

**Related:** [PLAN_FLAG_DISPUTE.md](PLAN_FLAG_DISPUTE.md), [PLAN_RESOLVE_DISPUTE.md](PLAN_RESOLVE_DISPUTE.md)
