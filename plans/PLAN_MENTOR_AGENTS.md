# PLAN: mentor_agents Domain

*Decentralized agent learning through the mesh.*

**Status:** Planning  
**Created:** 2026-02-04  
**Author:** Hecate 🗝️

---

## Vision

Thousands of Hecate agents learning from each other through the mesh. When one agent discovers a pattern or antipattern, that knowledge propagates to others — validated by trusted mentors, weighted by reputation.

**No central registry.** Learnings travel as FACTs on the mesh.

---

## Domain Overview

```
mentor_agents/
├── CMD Department (Processing)
│   ├── submit_learning/
│   ├── validate_learning/
│   ├── reject_learning/
│   ├── endorse_learning/
│   ├── dispute_learning/
│   ├── subscribe_to_mentor/
│   └── unsubscribe_from_mentor/
│
├── PRJ Department (Filing)
│   ├── learning_submitted_to_learnings/
│   ├── learning_validated_to_learnings/
│   ├── mentor_subscribed_to_subscriptions/
│   └── (emitters to mesh)
│
└── QRY Department (Inquiries)
    ├── find_learning/
    ├── list_learnings_by_category/
    ├── list_mentors/
    └── get_mentor_reputation/
```

---

## Dossiers

### Learning Dossier

**Stream ID:** `learning-{learning_id}`

A learning moves through desks, accumulating slips:

```
[submitted] → [validated|rejected] → [endorsed]* → [disputed]?
```

| Slip (Event) | Added At | Meaning |
|--------------|----------|---------|
| `learning_submitted_v1` | submit_learning | Agent proposes a learning |
| `learning_validated_v1` | validate_learning | Mentor approves |
| `learning_rejected_v1` | reject_learning | Mentor rejects with reason |
| `learning_endorsed_v1` | endorse_learning | Another agent vouches |
| `learning_disputed_v1` | dispute_learning | Someone challenges validity |
| `learning_dispute_resolved_v1` | resolve_learning_dispute | Dispute outcome |

### Mentor Subscription Dossier

**Stream ID:** `mentor-sub-{subscriber}-{mentor}`

```
[subscribed] → [unsubscribed]?
```

---

## Learning Schema

What does a "learning" contain?

```erlang
#{
    %% Identity
    id => binary(),                    % Unique learning ID
    
    %% Submitter
    submitter_id => binary(),          % Agent MRI who discovered this
    submitted_at => integer(),         % Timestamp
    
    %% Classification
    category => atom(),                % pattern | antipattern | example | correction
    domain => binary(),                % "erlang", "architecture", "naming", etc.
    tags => [binary()],                % ["vertical_slicing", "supervision", ...]
    
    %% Content
    title => binary(),                 % Short description
    description => binary(),           % Full explanation
    
    %% Evidence
    bad_example => binary() | undefined,   % Code/structure that's wrong
    good_example => binary() | undefined,  % Code/structure that's right
    context => binary(),               % When does this apply?
    
    %% Metadata
    severity => atom(),                % critical | important | suggestion
    confidence => float()              % Submitter's confidence (0.0-1.0)
}
```

---

## CMD Desks

### submit_learning/

Agent submits a new learning.

**Command:** `submit_learning_v1`
```erlang
#{
    learning => learning_schema(),     % The learning content
    source => atom()                   % discovered | taught | observed
}
```

**Event:** `learning_submitted_v1`

**Validation:**
- Learning has required fields
- Submitter has valid identity
- Not a duplicate (fuzzy match on title/content?)

---

### validate_learning/

Mentor validates a submitted learning.

**Command:** `validate_learning_v1`
```erlang
#{
    learning_id => binary(),
    mentor_id => binary(),
    notes => binary() | undefined,     % Optional mentor notes
    improvements => map() | undefined  % Suggested edits
}
```

**Event:** `learning_validated_v1`

**Validation:**
- Mentor has mentor status (reputation threshold?)
- Learning exists and is pending
- Mentor hasn't already validated this learning

---

### reject_learning/

Mentor rejects a submitted learning.

**Command:** `reject_learning_v1`
```erlang
#{
    learning_id => binary(),
    mentor_id => binary(),
    reason => binary(),                % Why rejected
    suggestions => binary() | undefined % How to improve
}
```

**Event:** `learning_rejected_v1`

---

### endorse_learning/

Any agent endorses a validated learning (vouch for quality).

**Command:** `endorse_learning_v1`
```erlang
#{
    learning_id => binary(),
    endorser_id => binary(),
    comment => binary() | undefined
}
```

**Event:** `learning_endorsed_v1`

**Validation:**
- Learning is validated (not pending/rejected)
- Endorser hasn't already endorsed
- Endorser is not the submitter

---

### dispute_learning/

Agent disputes a learning's validity.

**Command:** `dispute_learning_v1`
```erlang
#{
    learning_id => binary(),
    disputer_id => binary(),
    reason => binary(),
    counter_evidence => binary() | undefined
}
```

**Event:** `learning_disputed_v1`

---

### subscribe_to_mentor/

Agent subscribes to receive learnings from a mentor.

**Command:** `subscribe_to_mentor_v1`
```erlang
#{
    subscriber_id => binary(),
    mentor_id => binary()
}
```

**Event:** `mentor_subscribed_v1`

---

### unsubscribe_from_mentor/

**Command:** `unsubscribe_from_mentor_v1`
**Event:** `mentor_unsubscribed_v1`

---

## PRJ Desks (Projections)

### Local Read Models (SQLite)

```sql
-- Learnings table
CREATE TABLE learnings (
    id TEXT PRIMARY KEY,
    submitter_id TEXT NOT NULL,
    category TEXT NOT NULL,           -- pattern, antipattern, example, correction
    domain TEXT NOT NULL,
    tags TEXT,                         -- JSON array
    title TEXT NOT NULL,
    description TEXT,
    bad_example TEXT,
    good_example TEXT,
    context TEXT,
    severity TEXT,
    status TEXT DEFAULT 'pending',     -- pending, validated, rejected
    validated_by TEXT,
    endorsement_count INTEGER DEFAULT 0,
    dispute_count INTEGER DEFAULT 0,
    submitted_at INTEGER,
    validated_at INTEGER
);

CREATE INDEX idx_learnings_category ON learnings(category);
CREATE INDEX idx_learnings_domain ON learnings(domain);
CREATE INDEX idx_learnings_status ON learnings(status);

-- Mentor subscriptions
CREATE TABLE mentor_subscriptions (
    subscriber_id TEXT NOT NULL,
    mentor_id TEXT NOT NULL,
    subscribed_at INTEGER,
    PRIMARY KEY (subscriber_id, mentor_id)
);

-- Remote learnings (from mesh)
CREATE TABLE remote_learnings (
    id TEXT PRIMARY KEY,
    source_agent TEXT,                 -- Who published this to mesh
    learning_data TEXT,                -- JSON blob
    discovered_at INTEGER,
    applied BOOLEAN DEFAULT FALSE      -- Have we incorporated this?
);
```

### Emitters (to Mesh)

| Emitter | Topic | Purpose |
|---------|-------|---------|
| `learning_validated_to_mesh` | `hecate.learning.validated` | Broadcast validated learnings |
| `learning_endorsed_to_mesh` | `hecate.learning.endorsed` | Broadcast endorsements |
| `mentor_available_to_mesh` | `hecate.mentor.available` | Announce mentor status |

### Listeners (from Mesh)

| Listener | Topic | Purpose |
|----------|-------|---------|
| `remote_learning_listener` | `hecate.learning.validated` | Receive learnings from mentors |
| `mentor_discovery_listener` | `hecate.mentor.available` | Discover mentors on mesh |

---

## QRY Desks

### find_learning/

```erlang
find_learning:execute(#{id => LearningId}).
```

### list_learnings_by_category/

```erlang
list_learnings_by_category:execute(#{
    category => antipattern,
    domain => <<"erlang">>,
    status => validated,
    limit => 50
}).
```

### list_mentors/

```erlang
list_mentors:execute(#{
    domain => <<"architecture">>,
    min_reputation => 0.8
}).
```

---

## Mesh Integration

### Publishing Learnings

When a learning is validated by a mentor:
1. `learning_validated_v1` event stored locally
2. `learning_validated_to_mesh` emitter publishes FACT
3. FACT includes full learning content + mentor signature

### Receiving Learnings

When a remote learning arrives:
1. `remote_learning_listener` receives FACT
2. Checks if from a subscribed mentor
3. If subscribed: stores in `remote_learnings`, optionally auto-applies
4. If not subscribed: stores for manual review

### Mentor Discovery

Agents can discover mentors on the mesh:
1. Query `hecate.mentor.available` topic
2. Receive mentor profiles (reputation, domains, follower count)
3. Subscribe to interesting mentors

---

## Reputation Integration

Ties into existing `manage_reputation` domain:

- Submitting validated learnings → reputation boost
- Endorsements from high-rep agents → more weight
- Disputed learnings → reputation impact
- Mentor status requires reputation threshold

---

## Open Questions

### 1. How does an agent become a mentor?

Options:
- Reputation threshold (auto-promotion)
- Nomination by existing mentors
- Human approval
- Domain-specific (mentor for Erlang ≠ mentor for architecture)

### 2. Learning versioning

Learnings may evolve. How to handle:
- Updates to existing learnings?
- Deprecation of outdated learnings?
- Conflicting learnings?

### 3. Privacy/Sanitization

Learnings might contain:
- User-specific context
- Proprietary code snippets
- Sensitive information

Need sanitization before publishing to mesh.

### 4. Local vs Global

Should all learnings propagate globally, or:
- Some stay local (agent-specific)
- Some propagate to org (private mesh)
- Some go public (global mesh)

### 5. Auto-application

When receiving a learning from a trusted mentor:
- Auto-incorporate into local skills?
- Queue for review?
- Depends on confidence/severity?

---

## Implementation Phases

### Phase 1: Local Learning Store

- [ ] Create `mentor_agents` app structure
- [ ] Implement `submit_learning/` desk
- [ ] Implement basic projections
- [ ] Local query capability

### Phase 2: Mentor Validation

- [ ] Implement `validate_learning/` desk
- [ ] Implement `reject_learning/` desk
- [ ] Mentor status checks (tie to reputation)

### Phase 3: Mesh Publishing

- [ ] Implement emitters to mesh
- [ ] Define FACT schemas
- [ ] Implement listeners for remote learnings

### Phase 4: Subscription Model

- [ ] Implement `subscribe_to_mentor/` desk
- [ ] Mentor discovery on mesh
- [ ] Filtered learning propagation

### Phase 5: Endorsement & Disputes

- [ ] Implement `endorse_learning/` desk
- [ ] Implement `dispute_learning/` desk
- [ ] Reputation impacts

---

## File Structure (Projected)

```
apps/mentor_agents/
├── src/
│   ├── mentor_agents_app.erl
│   ├── mentor_agents_sup.erl
│   ├── mentor_agents_store.erl
│   │
│   ├── submit_learning/
│   │   ├── submit_learning_desk_sup.erl
│   │   ├── submit_learning_v1.erl
│   │   ├── learning_submitted_v1.erl
│   │   ├── maybe_submit_learning.erl
│   │   ├── submit_learning_responder_v1.erl
│   │   └── learning_submitted_to_mesh.erl
│   │
│   ├── validate_learning/
│   │   └── ...
│   │
│   └── subscribe_to_mentor/
│       └── ...
│
└── rebar.config
```

---

*Agents teaching agents. The mesh becomes a classroom.* 🗝️
