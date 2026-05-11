# API contract — `library_api`

The single public surface of `resolve_mesh_names`. See `PLAN_RESOLVE_MESH_NAMES_PART1` §3 for the canonical contract; this file is a placeholder pointer.

Functions:
- `resolve/2` — single-shot MRI resolution → verified records
- `watch/3` — push subscription, delivers messages to caller's mailbox
- `unwatch/1` — cancel a subscription (idempotent)
- `describe/2` — composite query (records + endorsements + backlinks + consensus)
- `verify_trust_chain/3` — explicit 5-link walk
- `backlinks/2` — reverse-direction query
- `refresh/2` — invalidate L5 cache for an MRI and re-resolve

No qnames in the API. No RRsets. No TTLs (push-driven primary; TTL is fallback). No rcodes (clean Erlang `{ok, _} | {error, atom()}`).

Wire bridges translate to wire-protocol shape at their own boundary. They never own naming, trust, or cache state.
