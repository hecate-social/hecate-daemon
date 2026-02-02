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

**Get daemon operational + pairing flow working.**

Pairing is split across daemon, TUI, and realm. Coordinate accordingly.

---

## Active Tasks

### HIGH: Implement Mesh Connection

The TODOs in `hecate_mesh.erl` reveal the gap:

```
apps/hecate_mesh/src/hecate_mesh.erl:45  TODO: Implement actual mesh connection
apps/hecate_mesh/src/hecate_mesh.erl:67  TODO: Implement mesh publishing
apps/hecate_mesh/src/hecate_mesh.erl:89  TODO: Implement mesh subscription
```

Report in RESPONSES.md:
- Current state of `hecate_mesh.erl`
- What Macula client library exists (hex package? HTTP/3 direct?)
- Proposed approach

### HIGH: Pairing API (Daemon Side)

The TUI will handle the UX. Daemon provides the API:

| Endpoint | Purpose |
|----------|---------|
| `POST /api/pairing/start` | Start pairing session, return session_id, code, URL |
| `GET /api/pairing/status` | Poll for confirmation status |
| `POST /api/pairing/cancel` | Cancel active pairing |
| `GET /api/identity` | Return current identity and pairing status |

Verify `src/hecate_pairing.erl`:
1. Does it expose these endpoints via `hecate_api`?
2. Does it call the realm API correctly?
3. Does it store cert on success?

Report in RESPONSES.md:
- Current API endpoints available
- What's missing
- Realm API endpoints it expects

### MEDIUM: Document Bootstrap Flow

How does a fresh daemon go from zero to operational?

1. `hecate init` → Generate keypair, create MRI
2. `hecate start` → Start daemon on :4444
3. TUI pairing flow → Pair with realm
4. Announce capabilities
5. Start serving RPC

Document in RESPONSES.md.

---

## Dependency Note

**Pairing requires TUI.** The daemon provides the API, but the user experience (QR display, status) lives in the TUI.

Coordinate with `hecate-tui/.hecate/QUEUE.md` for the TUI side.

---

## Completed Tasks

### ✅ Mesh Integration Refactor (Phases 1-6)
### ✅ Dialyzer Cleanup
### ✅ Codebase Verification (61 tests pass)
### ✅ v0.1.1 Self-Extracting Release

---

*— Hecate*
