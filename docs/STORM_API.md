# Big Picture Event Storming API

## Overview

Big Picture Event Storming is a collaborative workshop technique used during the **Discovery** phase of the venture lifecycle. Participants generate domain event ideas on "sticky notes," then progressively organize them into stacks, clusters, and eventually divisions (bounded contexts).

In Hecate, this entire process is event-sourced. Every sticky posted, stacked, clustered, or promoted is recorded as a domain event on the venture's aggregate stream. The API exposes this as a set of POST commands (writes) and GET queries (reads) accessible via the daemon's Unix socket.

**Prerequisites**: A venture must be initiated and discovery must be active (`start_discovery`) before a storm can begin.

## Concepts

| Concept | Description |
|---------|-------------|
| **Event Sticky** | A single domain event idea (the orange sticky note). Has `text`, `author`, and `weight`. |
| **Stack** | A group of duplicate or similar stickies. Created automatically when the first sticky is stacked onto another. |
| **Groom** | Pick the best-named sticky from a stack as the canonical representative. Absorbed stickies are removed; the canonical sticky's weight equals the stack size. |
| **Cluster** | A grouping of related stickies that forms a candidate bounded context. Created automatically when the first sticky is clustered with a target cluster ID. |
| **Fact Arrow** | A causal/data-flow relationship between two clusters, labeled with a fact name (e.g., "order_placed"). |
| **Phase** | The current stage of the storming process. Phases advance linearly. |
| **Division** | A promoted cluster becomes a division (bounded context) in the venture. |

## Phases

The storm progresses through these phases in order:

```
storm -> stack -> groom -> cluster -> name -> map -> promoted
```

| Phase | Purpose | Typical Activities |
|-------|---------|-------------------|
| `storm` | Free-form brainstorming | Post event stickies, pull bad ones |
| `stack` | Group duplicates | Stack similar stickies together |
| `groom` | Pick canonical names | Groom each stack to choose best wording |
| `cluster` | Form bounded contexts | Cluster stickies into logical groups |
| `name` | Name the clusters | Give each cluster a business name |
| `map` | Draw relationships | Draw fact arrows between clusters |
| `promoted` | Finalize | Promote clusters to divisions |

Phase advancement is explicit via `advance_storm_phase`. The phase constrains what operations make sense but does not hard-block most commands -- the constraint is on the aggregate's `VL_STORMING` status flag (the storm must be active for any sticky/cluster/arrow operation).

## Connection

All API calls go through the daemon's Unix socket:

```bash
export SOCK=/run/hecate/daemon.sock
curl --unix-socket $SOCK http://localhost/api/...
```

## Response Format

**Success responses** return the operation result directly as JSON:

```json
{
  "venture_id": "...",
  ...
}
```

**Query success responses** use the `json_ok` wrapper which merges `{"ok": true}`:

```json
{
  "ok": true,
  "storm": { ... }
}
```

**Error responses** always include `ok: false`:

```json
{
  "ok": false,
  "error": "reason_as_string"
}
```

## API Reference

---

### Storm Lifecycle

#### Start Storm

Starts a new Big Picture Event Storming session. Increments the storm number. Requires discovery to be active and no storm currently running.

```
POST /api/ventures/:venture_id/storm/start
```

**Request body**: None required.

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "version": 5,
  "events": [
    {
      "event_type": "big_picture_storm_started_v1",
      "venture_id": "vent-abc123",
      "storm_number": 1,
      "started_at": 1707840000000
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `discovery_not_active` | Discovery hasn't been started yet |
| 422 | `storm_already_active` | A storm is already in progress |

---

#### Shelve Storm

Pauses the storm session. The storm can be resumed later.

```
POST /api/ventures/:venture_id/storm/shelve
```

**Request body** (optional):

```json
{
  "reason": "lunch break"
}
```

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "shelved": true,
  "version": 12,
  "events": [
    {
      "event_type": "big_picture_storm_shelved_v1",
      "venture_id": "vent-abc123",
      "shelved_at": 1707843600000
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm to shelve |

---

#### Resume Storm

Resumes a previously shelved storm session. Returns to the `storm` phase.

```
POST /api/ventures/:venture_id/storm/resume
```

**Request body**: None required.

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "resumed": true,
  "version": 13,
  "events": [
    {
      "event_type": "big_picture_storm_resumed_v1",
      "venture_id": "vent-abc123"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_shelved` | Storm is not in shelved state |

---

#### Archive Storm

Permanently closes the storm session. Clears all stickies, stacks, clusters, and arrows from the aggregate state. This is irreversible (the events remain in the event store but the aggregate resets).

```
POST /api/ventures/:venture_id/storm/archive
```

**Request body**: None required.

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "archived": true,
  "version": 30,
  "events": [
    {
      "event_type": "big_picture_storm_archived_v1",
      "venture_id": "vent-abc123"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `no_storm_to_archive` | No active or shelved storm exists |

---

### Event Stickies

#### Post Event Sticky

Adds a new event sticky to the board. Each sticky gets a generated `sticky_id`, starts with `weight: 1`, and belongs to no stack or cluster.

```
POST /api/ventures/:venture_id/storm/sticky
```

**Request body**:

```json
{
  "text": "order placed",
  "author": "alice"
}
```

| Field | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `text` | string | yes | -- | The domain event name/description |
| `author` | string | no | `"user"` | Who posted this sticky |

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "sticky_id": "stk-uuid-here",
  "text": "order placed",
  "events": [
    {
      "event_type": "event_sticky_posted_v1",
      "venture_id": "vent-abc123",
      "sticky_id": "stk-uuid-here",
      "text": "order placed",
      "author": "alice",
      "created_at": 1707840100000
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `text is required` | Missing `text` field |
| 400 | `text cannot be empty` | Empty string for `text` |
| 422 | `storm_not_active` | No active storm |

---

#### Pull Event Sticky

Removes a sticky from the board. The sticky is deleted from aggregate state.

```
POST /api/ventures/:venture_id/storm/sticky/:sticky_id/pull
```

**Request body**: None required.

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "sticky_id": "stk-uuid-here"
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm |
| 422 | `sticky_not_found` | The sticky ID doesn't exist |

---

### Stacking

#### Stack Event Sticky

Stacks a sticky onto a target sticky. If no stack exists yet for the target, a new stack emerges automatically (emitting `event_stack_emerged_v1`), and both the source and target stickies join it.

```
POST /api/ventures/:venture_id/storm/sticky/:sticky_id/stack
```

**Request body**:

```json
{
  "target_sticky_id": "stk-target-uuid"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `target_sticky_id` | string | yes | The sticky to stack onto |

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "sticky_id": "stk-source-uuid",
  "target_sticky_id": "stk-target-uuid",
  "events": [
    {
      "event_type": "event_stack_emerged_v1",
      "stack_id": "stack-uuid",
      "color": "#FFB347"
    },
    {
      "event_type": "event_sticky_stacked_v1",
      "sticky_id": "stk-source-uuid",
      "stack_id": "stack-uuid"
    }
  ]
}
```

The response may include one or two events:
- `event_stack_emerged_v1` -- only emitted when this is the first stack operation on the target (a new stack is created)
- `event_sticky_stacked_v1` -- always emitted, recording the source sticky joining the stack

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `target_sticky_id is required` | Missing field |
| 400 | `target_sticky_id cannot be empty` | Empty string |
| 422 | `storm_not_active` | No active storm |

---

#### Unstack Event Sticky

Removes a sticky from its current stack.

```
POST /api/ventures/:venture_id/storm/sticky/:sticky_id/unstack
```

**Request body**: None required.

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "sticky_id": "stk-uuid-here",
  "events": [
    {
      "event_type": "event_sticky_unstacked_v1",
      "sticky_id": "stk-uuid-here",
      "stack_id": "stack-uuid"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm |

---

### Grooming

#### Groom Event Stack

Selects a canonical sticky from a stack. The canonical sticky's weight is set to the total stack size. All other stickies in the stack (the "absorbed" ones) are removed from the board. The stack itself is dissolved.

```
POST /api/ventures/:venture_id/storm/stack/:stack_id/groom
```

**Request body**:

```json
{
  "canonical_sticky_id": "stk-best-name-uuid"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `canonical_sticky_id` | string | yes | The sticky with the best event name |

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "stack_id": "stack-uuid",
  "canonical_sticky_id": "stk-best-name-uuid",
  "events": [
    {
      "event_type": "event_stack_groomed_v1",
      "stack_id": "stack-uuid",
      "canonical_sticky_id": "stk-best-name-uuid",
      "weight": 4,
      "absorbed_sticky_ids": ["stk-2", "stk-3", "stk-4"]
    }
  ]
}
```

After grooming, the canonical sticky stands alone (no longer in a stack) with its weight reflecting how many duplicates existed. Higher weight means more participants independently identified this event.

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `canonical_sticky_id is required` | Missing field |
| 400 | `canonical_sticky_id cannot be empty` | Empty string |
| 422 | `storm_not_active` | No active storm |

---

### Clustering

#### Cluster Event Sticky

Assigns a sticky to a cluster. If the `target_cluster_id` doesn't exist yet, a new cluster emerges automatically (emitting `event_cluster_emerged_v1`).

```
POST /api/ventures/:venture_id/storm/sticky/:sticky_id/cluster
```

**Request body**:

```json
{
  "target_cluster_id": "clust-uuid"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `target_cluster_id` | string | yes | Cluster to assign the sticky to. Can be a new ID to create a cluster. |

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "sticky_id": "stk-uuid-here",
  "version": 15,
  "events": [
    {
      "event_type": "event_cluster_emerged_v1",
      "cluster_id": "clust-uuid",
      "color": "#87CEEB"
    },
    {
      "event_type": "event_sticky_clustered_v1",
      "sticky_id": "stk-uuid-here",
      "cluster_id": "clust-uuid"
    }
  ]
}
```

The response may include:
- `event_cluster_emerged_v1` -- only when the cluster is new
- `event_sticky_clustered_v1` -- always emitted

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `target_cluster_id is required` | Missing field |
| 400 | `target_cluster_id cannot be empty` | Empty string |
| 422 | `storm_not_active` | No active storm |

---

#### Uncluster Event Sticky

Removes a sticky from its current cluster.

```
POST /api/ventures/:venture_id/storm/sticky/:sticky_id/uncluster
```

**Request body**: None required.

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "sticky_id": "stk-uuid-here",
  "version": 16,
  "events": [
    {
      "event_type": "event_sticky_unclustered_v1",
      "sticky_id": "stk-uuid-here",
      "cluster_id": "clust-uuid"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm |

---

#### Dissolve Event Cluster

Dissolves a cluster entirely. All stickies in the cluster are unclustered (returned to the board as free stickies). The cluster's status becomes `dissolved`.

```
POST /api/ventures/:venture_id/storm/cluster/:cluster_id/dissolve
```

**Request body**: None required.

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "cluster_id": "clust-uuid",
  "version": 17,
  "events": [
    {
      "event_type": "event_cluster_dissolved_v1",
      "cluster_id": "clust-uuid"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm |

---

#### Name Event Cluster

Assigns a business name to a cluster (e.g., "Order Fulfillment", "Payment Processing").

```
POST /api/ventures/:venture_id/storm/cluster/:cluster_id/name
```

**Request body**:

```json
{
  "name": "Order Fulfillment"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `name` | string | yes | The business name for this cluster |

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "cluster_id": "clust-uuid",
  "name": "Order Fulfillment",
  "version": 18,
  "events": [
    {
      "event_type": "event_cluster_named_v1",
      "cluster_id": "clust-uuid",
      "name": "Order Fulfillment"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `name is required` | Missing field |
| 400 | `name cannot be empty` | Empty string |
| 422 | `storm_not_active` | No active storm |

---

#### Promote Event Cluster

Promotes a named cluster to a division (bounded context). This emits two events: `event_cluster_promoted_v1` and `division_identified_v1`. The cluster's status becomes `promoted`, and a new division is registered in the venture.

```
POST /api/ventures/:venture_id/storm/cluster/:cluster_id/promote
```

**Request body**: None required.

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "cluster_id": "clust-uuid",
  "division_id": "div-uuid",
  "version": 25,
  "events": [
    {
      "event_type": "event_cluster_promoted_v1",
      "cluster_id": "clust-uuid"
    },
    {
      "event_type": "division_identified_v1",
      "venture_id": "vent-abc123",
      "division_id": "div-uuid",
      "context_name": "Order Fulfillment"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm |

---

### Fact Arrows

#### Draw Fact Arrow

Draws a directed arrow between two clusters, labeled with a fact name. Represents a causal or data-flow dependency (e.g., cluster A publishes "order_placed" which cluster B consumes).

```
POST /api/ventures/:venture_id/storm/fact
```

**Request body**:

```json
{
  "from_cluster": "clust-orders",
  "to_cluster": "clust-shipping",
  "fact_name": "order_placed"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `from_cluster` | string | yes | Source cluster ID |
| `to_cluster` | string | yes | Target cluster ID |
| `fact_name` | string | yes | The integration fact label |

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "arrow_id": "arrow-uuid",
  "from_cluster": "clust-orders",
  "to_cluster": "clust-shipping",
  "fact_name": "order_placed",
  "version": 20,
  "events": [
    {
      "event_type": "fact_arrow_drawn_v1",
      "arrow_id": "arrow-uuid",
      "from_cluster": "clust-orders",
      "to_cluster": "clust-shipping",
      "fact_name": "order_placed"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `from_cluster is required` | Missing field |
| 400 | `to_cluster is required` | Missing field |
| 400 | `fact_name is required` | Missing field |
| 422 | `storm_not_active` | No active storm |

---

#### Erase Fact Arrow

Removes a fact arrow from the board.

```
POST /api/ventures/:venture_id/storm/fact/:arrow_id/erase
```

**Request body**: None required.

**Response** (200):

```json
{
  "venture_id": "vent-abc123",
  "arrow_id": "arrow-uuid",
  "version": 21,
  "events": [
    {
      "event_type": "fact_arrow_erased_v1",
      "arrow_id": "arrow-uuid"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 422 | `storm_not_active` | No active storm |

---

### Phase Control

#### Advance Storm Phase

Explicitly advances the storm to the next phase. The phase must follow the valid transition sequence.

```
POST /api/ventures/:venture_id/storm/phase/advance
```

**Request body**:

```json
{
  "target_phase": "stack"
}
```

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `target_phase` | string | yes | The phase to advance to |

Valid `target_phase` values: `"stack"`, `"groom"`, `"cluster"`, `"name"`, `"map"`, `"promoted"`

**Response** (201):

```json
{
  "venture_id": "vent-abc123",
  "target_phase": "stack",
  "events": [
    {
      "event_type": "storm_phase_advanced_v1",
      "venture_id": "vent-abc123",
      "phase": "stack",
      "previous_phase": "storm"
    }
  ]
}
```

**Errors**:

| Code | Error | Cause |
|------|-------|-------|
| 400 | `target_phase is required` | Missing field |
| 400 | `target_phase cannot be empty` | Empty string |
| 422 | `storm_not_active` | No active storm |
| 422 | `invalid_phase_transition` | Target phase is not the valid next step |

---

### Queries

#### Get Storm State

Returns the full current state of the storm: session info, all stickies, clusters, and fact arrows. Assembled from the SQLite read model.

```
GET /api/ventures/:venture_id/storm/state
```

**Response** (200):

```json
{
  "ok": true,
  "storm": {
    "phase": "cluster",
    "storm_number": 1,
    "started_at": 1707840000000,
    "shelved_at": null,
    "stickies": [
      {
        "sticky_id": "stk-1",
        "text": "order placed",
        "author": "alice",
        "weight": 3,
        "stack_id": null,
        "cluster_id": "clust-orders",
        "created_at": 1707840100000
      },
      {
        "sticky_id": "stk-5",
        "text": "payment received",
        "author": "bob",
        "weight": 1,
        "stack_id": null,
        "cluster_id": "clust-payments",
        "created_at": 1707840200000
      }
    ],
    "clusters": [
      {
        "cluster_id": "clust-orders",
        "name": "Order Fulfillment",
        "color": "#87CEEB",
        "status": "active",
        "created_at": 1707841000000
      },
      {
        "cluster_id": "clust-payments",
        "name": null,
        "color": "#FFB6C1",
        "status": "active",
        "created_at": 1707841100000
      }
    ],
    "arrows": [
      {
        "arrow_id": "arrow-1",
        "from_cluster": "clust-orders",
        "to_cluster": "clust-payments",
        "fact_name": "order_placed",
        "created_at": 1707842000000
      }
    ]
  }
}
```

When no storm has been started, the response returns a default empty state:

```json
{
  "ok": true,
  "storm": {
    "phase": "ready",
    "storm_number": 0,
    "stickies": [],
    "clusters": [],
    "arrows": []
  }
}
```

---

#### Get Venture Events (Raw Event Stream)

Returns paginated raw events from the venture's event store stream. Useful for debugging, auditing, or replaying history. Includes all venture events (not just storm events).

```
GET /api/ventures/:venture_id/events?offset=0&limit=50
```

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `offset` | integer | `0` | Starting position in the event stream |
| `limit` | integer | `50` | Maximum number of events to return |

**Response** (200):

```json
{
  "ok": true,
  "events": [
    {
      "event_type": "venture_initiated_v1",
      "data": { ... },
      "version": 0,
      "timestamp": 1707830000000
    },
    {
      "event_type": "big_picture_storm_started_v1",
      "data": { ... },
      "version": 4,
      "timestamp": 1707840000000
    },
    {
      "event_type": "event_sticky_posted_v1",
      "data": { ... },
      "version": 5,
      "timestamp": 1707840100000
    }
  ],
  "offset": 0,
  "limit": 50,
  "count": 3
}
```

---

## Phase Transitions

```
  storm ──> stack ──> groom ──> cluster ──> name ──> map ──> promoted
```

Only forward transitions are valid. You cannot skip phases or go backwards. The transition is enforced by the `maybe_advance_storm_phase` handler.

| From | To | What Happened | What Comes Next |
|------|----|---------------|-----------------|
| (none) | `storm` | Storm started | Brainstorm: post stickies freely |
| `storm` | `stack` | Brainstorming done | Group duplicate/similar stickies |
| `stack` | `groom` | Stacking done | Pick canonical names from each stack |
| `groom` | `cluster` | Grooming done | Group related stickies into clusters |
| `cluster` | `name` | Clustering done | Name each cluster with a business name |
| `name` | `map` | Naming done | Draw fact arrows between clusters |
| `map` | `promoted` | Mapping done | Promote clusters to divisions |

Special lifecycle states (not part of phase sequence):
- **`shelved`** -- Storm paused via `shelve`. Resume returns to `storm` phase.
- **`ready`** -- No storm has been started yet (returned by the query when no session exists).

---

## curl Examples

All examples assume this setup:

```bash
export SOCK=/run/hecate/daemon.sock
export VID="your-venture-id-here"
```

### Full Workflow

```bash
# 1. Start the storm
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/start | jq .

# 2. Post some stickies
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"text": "order placed", "author": "alice"}' \
  http://localhost/api/ventures/$VID/storm/sticky | jq .

curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"text": "order created", "author": "bob"}' \
  http://localhost/api/ventures/$VID/storm/sticky | jq .

curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"text": "payment received", "author": "alice"}' \
  http://localhost/api/ventures/$VID/storm/sticky | jq .

# 3. Check current state
curl -s --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/state | jq .

# 4. Advance to stack phase
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"target_phase": "stack"}' \
  http://localhost/api/ventures/$VID/storm/phase/advance | jq .

# 5. Stack duplicates (assume STK1 and STK2 are sticky IDs from step 2)
export STK1="sticky-id-1"
export STK2="sticky-id-2"
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d "{\"target_sticky_id\": \"$STK1\"}" \
  http://localhost/api/ventures/$VID/storm/sticky/$STK2/stack | jq .

# 6. Advance to groom phase
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"target_phase": "groom"}' \
  http://localhost/api/ventures/$VID/storm/phase/advance | jq .

# 7. Groom the stack (pick the best name)
export STACK_ID="stack-id-from-step-5"
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d "{\"canonical_sticky_id\": \"$STK1\"}" \
  http://localhost/api/ventures/$VID/storm/stack/$STACK_ID/groom | jq .

# 8. Advance to cluster phase
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"target_phase": "cluster"}' \
  http://localhost/api/ventures/$VID/storm/phase/advance | jq .

# 9. Cluster stickies (use any ID as cluster ID -- cluster emerges on first use)
export CLUST="clust-orders"
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d "{\"target_cluster_id\": \"$CLUST\"}" \
  http://localhost/api/ventures/$VID/storm/sticky/$STK1/cluster | jq .

# 10. Advance to name phase
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"target_phase": "name"}' \
  http://localhost/api/ventures/$VID/storm/phase/advance | jq .

# 11. Name the cluster
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"name": "Order Fulfillment"}' \
  http://localhost/api/ventures/$VID/storm/cluster/$CLUST/name | jq .

# 12. Advance to map phase
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"target_phase": "map"}' \
  http://localhost/api/ventures/$VID/storm/phase/advance | jq .

# 13. Draw fact arrows between clusters
export CLUST2="clust-payments"
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d "{\"from_cluster\": \"$CLUST\", \"to_cluster\": \"$CLUST2\", \"fact_name\": \"order_placed\"}" \
  http://localhost/api/ventures/$VID/storm/fact | jq .

# 14. Advance to promoted phase
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"target_phase": "promoted"}' \
  http://localhost/api/ventures/$VID/storm/phase/advance | jq .

# 15. Promote a cluster to a division
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/cluster/$CLUST/promote | jq .
```

### Shelve and Resume

```bash
# Shelve with reason
curl -s -X POST --unix-socket $SOCK \
  -H "Content-Type: application/json" \
  -d '{"reason": "taking a break"}' \
  http://localhost/api/ventures/$VID/storm/shelve | jq .

# Resume
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/resume | jq .
```

### Undo Operations

```bash
# Pull a sticky (remove it)
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/sticky/$STK1/pull | jq .

# Unstack a sticky
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/sticky/$STK1/unstack | jq .

# Uncluster a sticky
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/sticky/$STK1/uncluster | jq .

# Dissolve a cluster (unclusters all its stickies)
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/cluster/$CLUST/dissolve | jq .

# Erase a fact arrow
export ARROW_ID="arrow-id-here"
curl -s -X POST --unix-socket $SOCK \
  http://localhost/api/ventures/$VID/storm/fact/$ARROW_ID/erase | jq .
```

### View Raw Event History

```bash
# First page of events
curl -s --unix-socket $SOCK \
  "http://localhost/api/ventures/$VID/events?offset=0&limit=20" | jq .

# Next page
curl -s --unix-socket $SOCK \
  "http://localhost/api/ventures/$VID/events?offset=20&limit=20" | jq .
```

---

## Domain Events Reference

All events emitted by the storm API:

| Event Type | Emitted By | Description |
|------------|-----------|-------------|
| `big_picture_storm_started_v1` | `start` | Storm session begins |
| `big_picture_storm_shelved_v1` | `shelve` | Storm paused |
| `big_picture_storm_resumed_v1` | `resume` | Storm resumed from shelved |
| `big_picture_storm_archived_v1` | `archive` | Storm permanently closed |
| `event_sticky_posted_v1` | `sticky` | New sticky added |
| `event_sticky_pulled_v1` | `sticky/:id/pull` | Sticky removed |
| `event_stack_emerged_v1` | `sticky/:id/stack` | New stack created (auto) |
| `event_sticky_stacked_v1` | `sticky/:id/stack` | Sticky joined a stack |
| `event_sticky_unstacked_v1` | `sticky/:id/unstack` | Sticky left a stack |
| `event_stack_groomed_v1` | `stack/:id/groom` | Stack resolved to canonical sticky |
| `event_cluster_emerged_v1` | `sticky/:id/cluster` | New cluster created (auto) |
| `event_sticky_clustered_v1` | `sticky/:id/cluster` | Sticky assigned to cluster |
| `event_sticky_unclustered_v1` | `sticky/:id/uncluster` | Sticky removed from cluster |
| `event_cluster_dissolved_v1` | `cluster/:id/dissolve` | Cluster dissolved |
| `event_cluster_named_v1` | `cluster/:id/name` | Cluster given a name |
| `event_cluster_promoted_v1` | `cluster/:id/promote` | Cluster promoted to division |
| `division_identified_v1` | `cluster/:id/promote` | Division created from cluster |
| `fact_arrow_drawn_v1` | `fact` | Arrow drawn between clusters |
| `fact_arrow_erased_v1` | `fact/:id/erase` | Arrow removed |
| `storm_phase_advanced_v1` | `phase/advance` | Phase moved forward |

All events are emitted to both `pg` (internal process groups) and `mesh` (external Macula network).

---

## Error Code Summary

| HTTP Code | Meaning | Typical Causes |
|-----------|---------|----------------|
| 200 | OK | Successful read or idempotent write |
| 201 | Created | Successful write that creates/advances state |
| 400 | Bad Request | Missing required field, empty value, invalid command construction |
| 405 | Method Not Allowed | Used GET on a POST endpoint or vice versa |
| 422 | Unprocessable Entity | Business rule violation (wrong phase, storm not active, etc.) |
| 500 | Internal Server Error | Query/projection failure |
