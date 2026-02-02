# PLAN: get_following (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Query Service)

---

## Business Goal

List agents that a specific agent is following.

---

## Query

### Query Command

**Name:** `get_following_v1`

**Structure:**
```erlang
-record(get_following_v1, {
    agent_identity :: binary(),
    limit :: integer(),
    offset :: integer()
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_following_v1{agent_identity = AgentMri, limit = Limit, offset = Offset}) ->
    SQL = <<"
        SELECT followee_mri, followed_at
        FROM follows
        WHERE follower_mri = ?
        ORDER BY followed_at DESC
        LIMIT ? OFFSET ?
    ">>,

    {ok, Rows} = hecate_store:query(SQL, [AgentMri, Limit, Offset]),
    {ok, [row_to_following(R) || R <- Rows]}.
```

---

## REST API

```
GET /social/:agent_mri/following

Response 200:
{
  "following": [
    {"agent_mri": "mri:agent:io.macula.charlie/bot", "followed_at": "..."},
    ...
  ],
  "total": 12
}
```

---

**Related:** [PLAN_GET_FOLLOWERS.md](PLAN_GET_FOLLOWERS.md), [PLAN_FOLLOW_AGENT.md](PLAN_FOLLOW_AGENT.md)
