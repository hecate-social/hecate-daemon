# PLAN: get_capability (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Capabilities (Query Service)

---

## Business Goal

Retrieve detailed information about a single capability by MRI.

---

## Query

### Query Command

**Name:** `get_capability_v1`

**Structure:**
```erlang
-record(get_capability_v1, {
    capability_mri :: binary(),
    include_metadata :: boolean()      % Default: true
}).
```

---

### Handler

**Name:** `handle_get_capability`
**Module:** `src/../query_capabilities/get_capability/handle_get_capability.erl`

**Logic:**
Query `capabilities` table by MRI.

**Pseudocode:**
```erlang
handle(#get_capability_v1{capability_mri = MRI, include_metadata = IncludeMeta}) ->
    SQL = <<"
        SELECT capability_mri, agent_identity, tags, description,
               demo_procedure, metadata, announced_at, retracted
        FROM capabilities
        WHERE capability_mri = ?
    ">>,

    case hecate_store:query_one(SQL, [MRI]) of
        {ok, Row} -> {ok, row_to_capability(Row, IncludeMeta)};
        {error, not_found} -> {error, not_found}
    end.
```

---

## REST API

```
GET /capabilities/:mri

Response 200:
{
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
  "agent_identity": "mri:agent:io.macula.alice/bot",
  "tags": ["weather", "forecast"],
  "description": "Provides 5-day weather forecasts...",
  "demo_procedure": "io.macula.alice.weather.forecast",
  "metadata": {
    "version": "1.0.0",
    "license": "MIT"
  },
  "announced_at": "2026-01-31T10:00:00Z",
  "retracted": false
}

Response 404:
{
  "error": "not_found"
}
```

---

**Related:** [PLAN_LIST_CAPABILITIES.md](PLAN_LIST_CAPABILITIES.md), [PLAN_DISCOVER_CAPABILITIES.md](PLAN_DISCOVER_CAPABILITIES.md)
