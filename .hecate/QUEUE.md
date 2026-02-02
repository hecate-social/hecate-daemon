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

## ⚡ PRIORITY: MOVE FASTER

You've been idle since verification. The refactor was good work, but we're not done.

**The daemon is a skeleton.** Pretty bones, correct structure — but no flesh. The mesh connection is stubbed. The pairing flow doesn't work end-to-end. We have 61 tests for infrastructure that can't actually *do* anything yet.

**Expectation:** When you start your next session, pick up these tasks IMMEDIATELY. No planning documents. No architectural discussions. CODE.

---

## Active Tasks

### 🔴 CRITICAL: Implement Mesh Connection

**This is blocking everything else.** Without mesh, we're just a local daemon talking to itself.

```
apps/hecate_mesh/src/hecate_mesh.erl:45  TODO: Implement actual mesh connection
apps/hecate_mesh/src/hecate_mesh.erl:67  TODO: Implement mesh publishing
apps/hecate_mesh/src/hecate_mesh.erl:89  TODO: Implement mesh subscription
```

**Do this:**
1. Read `hecate_mesh.erl` — understand current stub
2. Check what Macula client exists (hex package? HTTP/3 direct?)
3. **IMPLEMENT IT** — even HTTP/2 initially, or mock for local testing
4. Report **COMPLETION**, not proposals

I don't need plans. I need working code.

### 🔴 CRITICAL: Pairing API (Daemon Side)

The TUI handles UX. Daemon provides the API:

| Endpoint | Purpose |
|----------|---------|
| `POST /api/pairing/start` | Start pairing session, return session_id, code, URL |
| `GET /api/pairing/status` | Poll for confirmation status |
| `POST /api/pairing/cancel` | Cancel active pairing |
| `GET /api/identity` | Return current identity and pairing status |

**Do this:**
1. Check `src/hecate_pairing.erl` and `apps/hecate_api/`
2. **IMPLEMENT** missing endpoints
3. Test with curl
4. Report **COMPLETION** with working curl examples

### 🟡 MEDIUM: Bootstrap Flow (After Above)

Document the WORKING flow once mesh and pairing exist:

1. `hecate init` → Generate keypair, create MRI
2. `hecate start` → Start daemon on :4444
3. TUI pairing flow → Pair with realm
4. Announce capabilities
5. Start serving RPC

This is documentation of working code, not aspirational design.

---

## ⚠️ No More Planning Phase

The refactor is done. The architecture is correct. You learned the patterns.

Now **ship features**. The next message I want to see in RESPONSES.md:

> "COMPLETE: Mesh connection working. Here's how to test it..."

Not:

> "QUESTION: Should I use HTTP/2 or HTTP/3?"

Figure it out. Make a decision. Build it. If it's wrong, we fix it. But a working wrong thing beats a perfect plan.

---

## Completed Tasks

### ✅ Mesh Integration Refactor (Phases 1-6)
### ✅ Dialyzer Cleanup
### ✅ Codebase Verification (61 tests pass)
### ✅ v0.1.1 Self-Extracting Release

---

*The goddess is watching. Move.* 🔥🗝️🔥
