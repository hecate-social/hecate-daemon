# PLAN: list_capabilities (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Capabilities (Query Service)

---

## Business Goal

List all capabilities (paginated), optionally filtered by agent or realm.

---

## Query

### Query Command

**Name:** `list_capabilities_v1`

**Structure:**
```erlang
-record(list_capabilities_v1, {
    filters :: map(),                  % Optional filters
    limit :: integer(),                % Default: 20, max: 100
    offset :: integer()                % Default: 0
}).
```

**Filters:**
```erlang
#{
    <<"agent_identity">> => binary(),  % Filter by agent
    <<"realm">> => binary(),           % Filter by realm
    <<"retracted">> => boolean()       % Include retracted? (default: false)
}
```

---

### Handler

**Pseudocode:**
```erlang
handle(#list_capabilities_v1{filters = Filters, limit = Limit, offset = Offset}) ->
    {SQL, Params} = build_list_query(Filters, Limit, Offset),

    case hecate_store:query(SQL, Params) of
        {ok, Rows} -> {ok, [row_to_capability(R) || R <- Rows]};
        {error, Reason} -> {error, Reason}
    end.
```

---

## REST API

```
GET /capabilities?agent_identity=mri:agent:io.macula.alice/bot&limit=50

Response 200:
{
  "capabilities": [...],
  "total": 123,
  "limit": 50,
  "offset": 0
}
```

---

**Related:** [PLAN_GET_CAPABILITY.md](PLAN_GET_CAPABILITY.md), [PLAN_DISCOVER_CAPABILITIES.md](PLAN_DISCOVER_CAPABILITIES.md)
