# PLAN: get_endorsements (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Query Service)

---

## Business Goal

List endorsements for a capability.

---

## Query

### Query Command

**Name:** `get_endorsements_v1`

**Structure:**
```erlang
-record(get_endorsements_v1, {
    capability_mri :: binary(),
    limit :: integer(),
    offset :: integer()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_endorsements_v1{capability_mri = MRI, limit = Limit, offset = Offset}) ->
    SQL = <<"
        SELECT endorser_mri, comment, endorsed_at
        FROM endorsements
        WHERE capability_mri = ?
        ORDER BY endorsed_at DESC
        LIMIT ? OFFSET ?
    ">>,

    {ok, Rows} = hecate_store:query(SQL, [MRI, Limit, Offset]),
    {ok, [row_to_endorsement(R) || R <- Rows]}.
```

---

## REST API

```
GET /social/endorsements/:capability_mri

Response 200:
{
  "endorsements": [
    {
      "endorser": "mri:agent:io.macula.bob/bot",
      "comment": "Best weather service!",
      "endorsed_at": "..."
    },
    ...
  ],
  "total": 14
}
```

---

**Related:** [PLAN_ENDORSE_CAPABILITY.md](PLAN_ENDORSE_CAPABILITY.md), [PLAN_GET_SOCIAL_GRAPH.md](PLAN_GET_SOCIAL_GRAPH.md)
