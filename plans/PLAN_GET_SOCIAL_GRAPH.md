# PLAN: get_social_graph (Query)

**Status:** Planning
**Created:** 2026-01-31
**Domain:** Social (Query Service)

---

## Business Goal

Get complete social graph data for visualization (followers + following + endorsements).

---

## Query

### Query Command

**Name:** `get_social_graph_v1`

**Structure:**
```erlang
-record(get_social_graph_v1, {
    agent_identity :: binary(),
    include_endorsements :: boolean()  % Default: true
}).
```

---

### Handler

**Pseudocode:**
```erlang
handle(#get_social_graph_v1{agent_identity = AgentMri, include_endorsements = IncludeEnd}) ->
    Followers = get_followers(AgentMri),
    Following = get_following(AgentMri),
    Endorsements = case IncludeEnd of
        true -> get_agent_endorsements(AgentMri);
        false -> []
    end,

    {ok, #{
        <<"followers">> => Followers,
        <<"following">> => Following,
        <<"endorsements">> => Endorsements
    }}.
```

---

## REST API

```
GET /social/:agent_mri/graph

Response 200:
{
  "followers": [...],
  "following": [...],
  "endorsements": [...]
}
```

---

**Related:** [PLAN_GET_FOLLOWERS.md](PLAN_GET_FOLLOWERS.md), [PLAN_GET_FOLLOWING.md](PLAN_GET_FOLLOWING.md)
