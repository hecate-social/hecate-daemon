# Protocol mapping — qname ↔ MRI

How `serve_dns_over_mesh` translates a DNS qname into an MRI (forward, on every
query) and back (reverse, for RR synthesis — PTR targets, SOA MNAME, SRV target).
Plan: `PLAN_DNS_OVER_MESH_PART1` §3. Implementation: `src/qname_to_mri/` — the
dispatcher `qname_to_mri.erl` (`resolve/1` forward, `format/1` reverse) plus the
per-MRI-type modules. `src/classify_qname/classify_qname.erl` does the
mesh-eligible-or-not check before `qname_to_mri` is even called.

## The mesh suffix

A qname is "mesh" iff it's under the configured suffix — app env
`serve_dns_over_mesh.mesh_suffix`, default **`macula.io.`**. The check is
label-boundary aware: `acme.macula.io.` is mesh, `evilmacula.io.` is not. A
non-mesh qname → `serve_query` answers REFUSED + EDE(`not_in_mesh_suffix`) (the
daemon never forwards queries upstream for the mesh suffix, and refuses to be a
recursive resolver for anything else). `<suffix>.` itself (e.g. `macula.io.`) →
the realm apex → `mri:realm:<realm>`.

## qname shape

```
<leaf>(.<inner-parts>)? ( ._<disc>.<parent-segment> )* . <org> . <reversed-realm> .
```

A **type-discriminator label** (`_…`) marks each parent→child transition. The
**leftmost** discriminator names the MRI type; everything left of it is the leaf
segment(s); everything right of it is the parent chain, ending in the **org**
(the terminal label before the reversed realm — it has no own discriminator). The
realm comes from the reversed-realm labels: DNS `…acme.macula.io.` → MRI realm
`macula.io`, org `acme`.

Example (nested): `api._s.counter._a.acme.macula.io.` → `_s` = service, `_a` =
app → `mri:service:macula.io/acme/counter/api`.

### Discriminator labels

| label | MRI type | | label | MRI type | | label | MRI type |
|---|---|---|---|---|---|---|---|
| `_u` | user | | `_d` | device | | `_p` | proc |
| `_a` | app | | `_st` | station | | `_t` | topic |
| `_s` | service | | `_cl` | cluster | | `_ar` | artifact |
| `_lo` | location | | `_z` | zone | | `_lic` | license |
| `_n` | network | | `_m` | model | | `_crt` | cert |
| `_ds` | dataset | | `_cfg` | config | | `_k` | key |
| `_cls` | class | | `_tx` | taxonomy | | | |

(The reverse map `format/1` uses is the same set; org/realm have no
discriminator.)

### Special-cased types

- **`station`** — qname is a single z-base-32 label before `._st.<suffix>`,
  carrying the 32-byte Ed25519 pubkey; the MRI has **no realm field**:
  `<z32>._st.macula.io.` ↔ `mri:station:<z32>`. Handled by `qname_station`
  (z32 decode/encode via `macula_z32`; the `station` MRI type landed in macula
  4.3.0).
- **`proc` / `topic`** — dot-flattening (§3.4.2): the leaf labels left of `._p`/
  `._t` get joined with `.` into a single MRI segment, and the parent chain must
  be exactly the org. `users.get._p.acme.macula.io.` ↔
  `mri:proc:macula.io/acme/users.get`. Built as an MRI string directly because
  `macula_mri:new/3`'s segment validator rejects `.` inside a segment (a macula
  4.x candidate: relax it for proc/topic segments).
- **reverse v6** — a qname under `ip6.arpa` (or `in-addr.arpa`) is detected
  before suffix-stripping and routed to `qname_reverse_v6` (pure `ip6.arpa`
  nibble decode; `resolve/1` currently returns `reverse_v6_lookup_required` — the
  PTR path through `resolve_mesh_names` isn't wired yet).

### Octet limits

RFC 1035: total qname ≤ 255 octets (incl. length octets), each label ≤ 63. A z32
pubkey label is 52 chars (fits). `qname_to_mri` validates both directions and
returns `name_too_long` / `malformed_qname` on violation.

## What resolves end-to-end today

`<z32>._st.macula.io.` (station — self-rooted in `resolve_mesh_names`, no realm
chain) and `mri:proc:...` qnames. `<name>._u.<realm>.macula.io.` / `._a.` / `._s.`
/ `._d.` parse fine but `resolve_mesh_names` returns `{error, {not_resolvable_yet, Type}}`
→ SERVFAIL + EDE(`not_resolvable_yet`) (the leaf-storage-key gap — no
MRI→storage-key mapping yet). See `apps/resolve_mesh_names/docs/API_CONTRACT.md`.

The result of `resolve_mesh_names_api:resolve/3` → an RFC 1035 RRset is
`synthesize_rr_set/`'s job; the error → rcode + EDE mapping is in `EDE_CODES.md`.
