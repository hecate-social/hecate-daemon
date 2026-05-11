# Trust chain — 5-link state machine

Placeholder pointer. See `PLAN_RESOLVE_MESH_NAMES_PART1` §5 for the canonical state machine + revocation primitives + cross-realm trust + bootstrap procedures.

Summary:
```
need_anchor → need_frtl → have_frtl → need_dir → have_dir →
need_endorse → have_endorse → need_leaf → have_leaf →
[need_hd?] → verified
```

Each transition reads from `cache_records` first; falls back to `lookup_via_dht` on miss. Every fail edge maps to a typed `{error, atom()}` returned to the caller. Wire bridges translate to wire-protocol responses at their own boundary.
