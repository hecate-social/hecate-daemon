# PLAN: get_followers (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Query Service)

---

## Business Goal

List agents following a specific agent.

---

## Query

### Query Command

**Name:** `get_followers_v1`

**Structure:**
```erlang
-record(get_followers_v1, {
    agent_identity :: binary(),
    limit :: integer(),
    offset :: integer()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_followers_v1{agent_identity = AgentMri, limit = Limit, offset = Offset}) ->
    SQL = <<"
        SELECT follower_mri, followed_at
        FROM follows
        WHERE followee_mri = ?
        ORDER BY followed_at DESC
        LIMIT ? OFFSET ?
    ">>,

    {ok, Rows} = hecate_store:query(SQL, [AgentMri, Limit, Offset]),
    {ok, [row_to_follower(R) || R <- Rows]}.
```

---

## REST API

```
GET /social/:agent_mri/followers

Response 200:
{
  "followers": [
    {"agent_mri": "mri:agent:io.macula.bob/bot", "followed_at": "..."},
    ...
  ],
  "total": 47
}
```

---

**Related:** [PLAN_GET_FOLLOWING.md](PLAN_GET_FOLLOWING.md), [PLAN_FOLLOW_AGENT.md](PLAN_FOLLOW_AGENT.md)
