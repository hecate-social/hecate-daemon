# DESIGN: Site Lifecycle

**Status:** Draft
**Created:** 2026-03-21
**Last Updated:** 2026-03-21

---

## Problem

Headless nodes (beam clusters, cell tower containers, datacenter servers) can't do OAuth — they have no browser. But they need realm membership to participate in the Macula mesh. Today, every node must independently join a realm, which requires a browser.

## Concept: Site

A **site** is a group of Erlang nodes that share a cookie. They form an Erlang cluster and replicate state via ReckonDB.

| Property | Value |
|----------|-------|
| Identity | Derived from cookie hash (deterministic) |
| Boundary | Erlang distribution (same cookie = same site) |
| Replication | ReckonDB distributed store |
| Realm membership | Site-level, not node-level |

### Site vs Node

| Concern | Scope | Store | Replicates? |
|---------|-------|-------|-------------|
| Node identity (keypair, DID) | Node | `settings_store` | No |
| Node preferences (theme, LLM) | Node | `settings_store` | No |
| Realm membership | Site | `site_store` | Yes |
| Site-wide config | Site | `site_store` | Yes |

## Scenarios

| Scenario | Site composition | How realm join happens |
|----------|-----------------|----------------------|
| Solo developer laptop | 1 node | OAuth on that node |
| Family, few laptops | N laptops, same WiFi | One does OAuth, rest cluster and inherit |
| Home microcluster | Dev machine + beam nodes | Dev machine does OAuth, beams inherit |
| Corporate office | Admin machine + servers | Admin does OAuth, servers inherit |
| Cell tower containers | N containers, no screens | Pre-provisioned with join token (see below) |
| Datacenter | Ops console + servers | Console does OAuth or API provisioning |

## Cookie Propagation

The Erlang cookie is the site's shared secret. How does it get to each node?

### Attended scenarios (human present)

The `install.sh` script (or NixOS config) sets the cookie during provisioning:

```
1. User installs hecate on first node (laptop)
   → Cookie auto-generated, saved to ~/.erlang.cookie
   → This IS the site cookie

2. User installs hecate on second node (beam00)
   → Installer asks: "Join existing site or create new?"
   → "Join existing" → user provides cookie (copy/paste, QR, or discovery)
   → Cookie saved to ~/.erlang.cookie
   → Node clusters with first node
   → site_store replicates → realm membership inherited
```

### Cookie exchange mechanisms

| Method | UX | Security | Best for |
|--------|-----|----------|----------|
| **Manual copy** | User copies cookie string | Medium (visible secret) | Dev/home |
| **QR code** | Attended node shows QR, new node scans | Good (ephemeral display) | Family/small team |
| **mDNS site advertisement** | Attended node broadcasts site invite on LAN | Medium (LAN-scoped) | Home/office LAN |
| **Join token** | Generate short-lived token on macula.io or CLI | High (time-limited, single-use) | Corporate, cell tower, datacenter |
| **NixOS/install.sh config** | Baked into provisioning config | High (pre-shared) | Infrastructure-as-code |

### Unattended scenarios (no human)

For cell towers, datacenters, and automated deployments:

```
1. Operator generates a "site provisioning token" on macula.io (or admin CLI)
   → Token encodes: realm, cookie (encrypted), expiry

2. Container/node boots with HECATE_SITE_TOKEN env var
   → Daemon decodes token → extracts cookie + realm
   → Sets cookie, joins cluster
   → site_store receives realm_joined_v1 (pre-confirmed)
```

This means the provisioning token is the **bootstrap mechanism** for unattended deploys. It bundles everything the node needs to join a site and realm in one artifact.

### mDNS site discovery (LAN only)

For the "family with laptops" and "home microcluster" cases, mDNS provides zero-config discovery:

```
1. First node boots, creates site, advertises via mDNS:
   _hecate-site._tcp.local → { site_id, cookie_hint, port }

2. Second node boots, discovers mDNS advertisement
   → Shows in UI: "Site 'rl's site' found on local network. Join?"
   → User confirms → cookie exchanged via secure channel (TLS + pin)
   → Node clusters, inherits realm
```

The `cookie_hint` is NOT the full cookie — it's enough for the UI to show which site is available. The actual cookie exchange happens over a TLS connection with user confirmation (like Bluetooth pairing).

## Architecture

### New store: `site_store`

```erlang
%% In hecate_app.erl ?STORES macro
site_store  %% mode => distributed (replicates across Erlang cluster)
```

**Critical:** `site_store` runs in `mode => distributed`, unlike all other stores which are `mode => single`. This is what makes realm membership propagate.

### New apps

```
apps/
├── guide_site_lifecycle/        ← CMD (process-centric)
│   ├── src/
│   │   ├── site_aggregate.erl
│   │   ├── site_state.erl
│   │   ├── site_status.hrl
│   │   ├── initiate_site/
│   │   │   ├── initiate_site_v1.erl          # command
│   │   │   ├── site_initiated_v1.erl         # event
│   │   │   └── maybe_initiate_site.erl       # handler
│   │   ├── join_realm/
│   │   │   ├── join_realm_v1.erl
│   │   │   ├── realm_joined_v1.erl
│   │   │   └── maybe_join_realm.erl
│   │   ├── leave_realm/
│   │   │   ├── leave_realm_v1.erl
│   │   │   ├── realm_left_v1.erl
│   │   │   └── maybe_leave_realm.erl
│   │   ├── admit_node/
│   │   │   ├── admit_node_v1.erl
│   │   │   ├── node_admitted_v1.erl
│   │   │   └── maybe_admit_node.erl
│   │   ├── remove_node/
│   │   │   ├── remove_node_v1.erl
│   │   │   ├── node_removed_v1.erl
│   │   │   └── maybe_remove_node.erl
│   │   └── guide_site_lifecycle_sup.erl
│   └── guide_site_lifecycle.app.src
│
├── project_site/                ← PRJ
│   ├── src/
│   │   ├── site_initiated/
│   │   │   └── site_initiated_v1_to_site.erl
│   │   ├── realm_joined/
│   │   │   └── realm_joined_v1_to_site.erl
│   │   ├── realm_left/
│   │   │   └── realm_left_v1_to_site.erl
│   │   ├── node_admitted/
│   │   │   └── node_admitted_v1_to_site_nodes.erl
│   │   ├── node_removed/
│   │   │   └── node_removed_v1_to_site_nodes.erl
│   │   ├── project_site_store.erl
│   │   └── project_site_sup.erl
│   └── project_site.app.src
│
├── query_site/                  ← QRY
│   ├── src/
│   │   ├── get_site/
│   │   │   └── get_site_api.erl
│   │   ├── get_site_nodes/
│   │   │   └── get_site_nodes_api.erl
│   │   ├── get_site_realm/
│   │   │   └── get_site_realm_api.erl
│   │   └── query_site_sup.erl
│   └── query_site.app.src
```

### Site aggregate

```erlang
-record(site_state, {
    site_id       :: binary(),            %% sha256(cookie)[:16] — deterministic
    realm         :: binary() | undefined,%% e.g., <<"io.macula">>
    realm_token   :: binary() | undefined,%% encrypted OAuth refresh token
    nodes         :: map(),               %% #{<<"rl@beam00">> => #{admitted_at => ...}}
    status        :: non_neg_integer(),   %% bit flags
    initiated_at  :: integer() | undefined
}).
```

**Stream ID:** `site-{site_id}` (single aggregate per site — singleton)

**Site ID derivation:**

```erlang
%% Deterministic — any node with the same cookie computes the same site_id
site_id_from_cookie() ->
    Cookie = erlang:get_cookie(),
    Hash = crypto:hash(sha256, atom_to_binary(Cookie)),
    binary:encode_hex(binary:part(Hash, 0, 8)).  %% 16 hex chars
```

No race condition. No "who boots first" problem. Every node with the same cookie computes the same `site_id` and writes to the same stream.

### Status bit flags

```erlang
-define(SITE_INITIATED,  1).   %% 2^0 — site exists
-define(SITE_REALM_JOINED, 2). %% 2^1 — site is part of a realm
-define(SITE_ARCHIVED,   4).   %% 2^2 — site decommissioned
```

### Event details

**`site_initiated_v1`**
```erlang
#{
    site_id => <<"a1b2c3d4e5f6g7h8">>,
    initiated_by => <<"rl@host00">>,   %% node that first booted
    initiated_at => 1711015200000
}
```

**`realm_joined_v1`**
```erlang
#{
    site_id => <<"a1b2c3d4e5f6g7h8">>,
    realm => <<"io.macula">>,
    realm_token => <<"encrypted:...">>,  %% encrypted with site cookie
    joined_by => <<"rl@host00">>,        %% node where OAuth happened
    joined_at => 1711015300000
}
```

**`node_admitted_v1`**
```erlang
#{
    site_id => <<"a1b2c3d4e5f6g7h8">>,
    node_name => <<"rl@beam00">>,
    admitted_at => 1711015400000
}
```

## Flows

### Flow 1: First boot (solo laptop)

```
1. hecate-daemon starts on laptop
2. No site_store events exist
3. Daemon computes site_id from cookie
4. Dispatches initiate_site_v1 → site_initiated_v1
5. UI shows "Not connected to a realm"
6. User clicks "Join Realm" → OAuth → realm_joined_v1
7. Done — site has 1 node, 1 realm
```

### Flow 2: Headless node joins existing site (beam00)

```
1. beam00 installed with same cookie as host00
   (via install.sh, NixOS config, or manual copy)
2. hecate-daemon starts, clusters with host00
3. site_store replicates from host00 → beam00
4. beam00 sees site_initiated_v1 + realm_joined_v1
5. beam00 dispatches admit_node_v1 for itself → node_admitted_v1
6. beam00 generates own node identity (settings_store, local)
7. beam00 connects to mesh using realm from site_store
8. Done — no browser needed
```

### Flow 3: Cell tower (unattended, no human)

```
1. Operator creates provisioning token on macula.io:
   POST /api/sites/provision → { token: "hct_...", expires: "..." }
   Token contains: realm, encrypted cookie, site_id

2. Container boots with HECATE_SITE_TOKEN=hct_...
3. Daemon decodes token → extracts cookie, realm, site_id
4. Sets cookie, connects to mesh
5. If first node: dispatches initiate_site_v1 + realm_joined_v1
   If joining existing: clusters, inherits from site_store
6. Dispatches admit_node_v1 for itself
7. Done — fully automated
```

### Flow 4: Family LAN (mDNS discovery)

```
1. Alice's laptop is running, site created, realm joined
2. Bob gets a new laptop, installs hecate
3. Bob's laptop discovers Alice's site via mDNS
4. Bob's UI shows: "Join Alice's site?"
5. Bob confirms → secure cookie exchange (TLS + confirmation code)
6. Bob's node clusters with Alice's
7. site_store replicates → Bob has realm membership
8. Bob's node auto-admits itself
9. Done — zero manual config
```

## What happens to existing realm_memberships apps?

The existing apps move realm-level concerns to the site:

| Current | Becomes | Reason |
|---------|---------|--------|
| `guide_realm_memberships` | **Replaced by** `guide_site_lifecycle` | Realm join is site-level |
| `project_realm_memberships` | **Replaced by** `project_site` | Realm projection is site-level |
| `query_realm_memberships` | **Replaced by** `query_site` | Realm query is site-level |
| `realm_memberships_store` | **Replaced by** `site_store` | Store moves to distributed mode |

The old apps can be archived once the migration is complete.

## ReckonDB distributed mode

### Current store modes

All stores in `hecate_app.erl` currently use `mode => single`. For `site_store`, we need `mode => distributed`.

**Question:** Does ReckonDB support `mode => distributed`?

ReckonDB uses Khepri/Ra under the hood. Distributed mode means:
- Ra consensus group across cluster nodes
- Automatic replication of events to all members
- Leader election for writes, reads from any node

This is ReckonDB's core value proposition — it's a distributed event store built on Raft. The `mode => single` we use today is actually the simpler case. Distributed mode should work, but we need to verify:

- [ ] ReckonDB `mode => distributed` works with current version
- [ ] New nodes joining the cluster automatically join the Ra group
- [ ] Event replication latency is acceptable (should be sub-second on LAN)
- [ ] What happens during network partitions (site split-brain)

## API endpoints

| Method | Path | Purpose |
|--------|------|---------|
| GET | `/api/site` | Get site info (id, realm, node count) |
| GET | `/api/site/nodes` | List admitted nodes |
| GET | `/api/site/realm` | Get realm info |
| POST | `/api/site/join-realm` | Start OAuth flow for realm join |
| POST | `/api/site/leave-realm` | Leave realm |
| POST | `/api/site/admit-node` | Manually admit a node |
| DELETE | `/api/site/nodes/:name` | Remove a node |

## Open questions

1. **Split-brain:** What if beam00+beam01 lose connectivity to host00? They still have the site_store. When connectivity returns, Ra will reconcile. But what if they diverge (e.g., one side leaves realm)?

2. **Cookie rotation:** If the cookie changes (security incident), the site_id changes. This is effectively a new site. Is that acceptable?

3. **Multi-realm:** Can a site belong to multiple realms? Current design says one realm per site. If multi-realm is needed, the aggregate changes to a set.

4. **Node auto-admit:** Should nodes auto-admit when they cluster, or require explicit admission? Auto-admit is simpler but less secure. Explicit admission allows an approval flow.

5. **Realm token storage:** The OAuth refresh token in `realm_joined_v1` needs to be encrypted. The cookie itself could be the encryption key (all site members have it). But this means anyone with the cookie can decrypt realm credentials.

6. **Provisioning token API:** Where does this live? On macula.io? On a self-hosted admin console? Both?

## Success criteria

- [ ] Solo laptop: OAuth join works as before
- [ ] beam00 clusters with host00, inherits realm membership without OAuth
- [ ] New node joining site auto-discovers site_id from cookie
- [ ] `site_store` replicates across all cluster nodes
- [ ] Site info visible in hecate-web UI
- [ ] Old `realm_memberships` apps cleanly replaced
