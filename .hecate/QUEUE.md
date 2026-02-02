# Hecate's Queue

*Commands from the goddess. Read and obey.*

---

## Protocol

| File | Your Access |
|------|-------------|
| `QUEUE.md` | **READ-ONLY** |
| `RESPONSES.md` | Write here |
| `STATUS.md` | Update here |

---

## Priority

**Get the daemon operational.** TUI can wait.

Focus areas:
1. Actual mesh connection (not just CQRS scaffolding)
2. Pairing flow end-to-end

---

## Active Tasks

### HIGH: Implement Mesh Connection

The TODOs in `hecate_mesh.erl` reveal the gap — we have beautiful CQRS architecture but no actual mesh.

```
apps/hecate_mesh/src/hecate_mesh.erl:45  TODO: Implement actual mesh connection
apps/hecate_mesh/src/hecate_mesh.erl:67  TODO: Implement mesh publishing
apps/hecate_mesh/src/hecate_mesh.erl:89  TODO: Implement mesh subscription
```

Review dependencies:
- What does the Macula mesh client look like?
- Is there a `macula` hex package to depend on?
- Or do we HTTP/3 (QUIC) directly?

Report in RESPONSES.md:
- Current state of `hecate_mesh.erl`
- What's needed to make it real
- Proposed approach

### HIGH: Verify Pairing Flow

`src/hecate_pairing.erl` exists with QR code pairing logic.

Verify:
1. Does it compile and work?
2. What realm API endpoints does it expect?
3. Is the flow complete: init → start_pairing → poll → paired?

Report in RESPONSES.md:
- Current state of pairing module
- Missing pieces
- What's needed on the realm side

### MEDIUM: Document Bootstrap Flow

How does a fresh daemon:
1. Initialize identity (keypair, MRI)
2. Connect to bootstrap nodes
3. Pair with a realm
4. Announce capabilities
5. Start serving RPC

Document the happy path in RESPONSES.md.

---

## Completed Tasks

### ✅ Mesh Integration Refactor (Phases 1-6)
### ✅ Dialyzer Cleanup
### ✅ Codebase Verification (compile, dialyzer, 61 tests pass)
### ✅ v0.1.1 Self-Extracting Release

---

## Context

The CQRS architecture is solid. Listeners, emitters, commands, projections — all in place.

What's missing is the **actual mesh connection** — the part that talks to other nodes.

Don't get distracted by polish. Make it work first.

---

*— Hecate*
