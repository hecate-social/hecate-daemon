# Composite queries — `describe` + `backlinks`

Two mesh-native queries that have no clean DNS analogue. Plan:
`PLAN_RESOLVE_MESH_NAMES_PART1` §4. Implementation: `src/describe_mri/` +
`src/backlinks/`.

## `describe/2,3`

Returns, in one call, everything a UI/operator wants about an MRI — what would be
4–6 separate DNS queries stitched client-side:

```erlang
#{ records      => [verified_record()],   %% from resolve_mri:resolve/2,3
   endorsements => [endorsement()],        %% currently [] — see below
   backlinks    => [link()] | {error, _},  %% from backlinks/2 — currently the error below
   consensus    => #{replicas => N, agreed => M},  %% currently #{replicas => 1, agreed => 1}
   last_modified => integer() | undefined,  %% ms epoch, from the records' versions/expiry
   partial      => boolean() }              %% true when a sub-query failed (it currently does, via backlinks)
```

Bounded latency: each sub-query runs under its own timeout (app env
`describe_total_timeout_ms`, default 2000 ms) and a failed sub-query degrades to
`[]`/`{error,_}` + `partial => true` rather than failing the whole call. If
`resolve` itself errors (e.g. `{not_resolvable_yet, Type}` for a user/app MRI),
`describe` returns that error.

**Honest stubs today:** `endorsements` is `[]` — the trust chain caches the
member pubkey in L3, not the full RME, so a non-empty `endorsements` needs a
fresh RME fetch (a follow-up). `consensus` is `#{replicas => 1, agreed => 1}` — a
real k-of-n quorum signal is a substrate feature (`lookup_via_dht` returns the
first station that answers; it doesn't yet poll N stations and report agreement).
`backlinks` is the error below, so `describe` always flags `partial` for now.

## `backlinks/2`

Intended: the reverse direction — "who endorsed this name", "who delegated to
this station" — from `realm_directory`'s trust-delegate listing + the RMEs that
cover this MRI's path, paginated (`backlinks_page_size`, default 50) for large
realms.

**Today it returns `{error, backlinks_not_yet_implemented}`** — honest, because
the SDK's RME schema has **no `path` field** (endorsements are realm-wide, not
path-scoped) and there's no reverse index in the DHT. Implementing it needs
either a storage_key/path → realm reverse index in `resolve_mesh_names`, or a new
realm-scoped backlink record in the SDK (a macula 4.4.0 candidate). Same index
gap blocks resolving `user`/`app`/`service`/`device` MRIs (see
`API_CONTRACT.md`).
