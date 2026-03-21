# DESIGN: Site Provisioning & Node Discovery

**Status:** Planning
**Created:** 2026-03-21

## Problem

A user gets a new machine, installs the OS, and wants to join their existing Hecate site. Today this requires SSH, manual cookie copying, and env var editing. It should be as easy as joining a WiFi network.

## Layers

### 1. LAN Discovery — "What's out there?"

Before joining anything, a new node needs to discover existing sites on the LAN.

**What's discoverable via standard protocols:**

| Protocol | What It Reveals | Security Risk |
|----------|----------------|---------------|
| mDNS/Avahi | hostname, IP, service type, TXT records | Low — LAN-scoped, standard |
| ARP | MAC address, IP | Low — L2 only |
| SSDP/UPnP | Device type, capabilities | Medium — can be spoofed |
| UDP broadcast | Custom — whatever we put in it | Medium — anyone on LAN sees it |

**What we SHOULD broadcast (via mDNS):**
- Service type: `_hecate._tcp.local`
- TXT: `site_id=E177AFAB88D85475` (public — just a hash)
- TXT: `version=0.16.5`
- TXT: `node_count=3`
- Port: 4444 (API)

**What we MUST NOT broadcast:**
- Cookie (secret — this IS the site's shared secret)
- Realm tokens (OAuth credentials)
- Node names (enumeration risk)
- Any credential material

### 2. Site Admin Role — "Who's in charge?"

**Question:** Who can admit new nodes to a site?

**Options:**

| Model | How It Works | Best For |
|-------|-------------|----------|
| **First node is admin** | The node that initiated the site has admin rights | Solo/small setups |
| **Any attended node** | Any node with a screen can approve join requests | Family |
| **Explicit admin flag** | Site admin must be explicitly designated | Corporate |
| **Quorum** | Majority of existing nodes must approve | High security |

**Proposed: Progressive model**
- Solo: first node is admin (automatic)
- When second node joins: admin explicitly promotes or approves
- Admin can delegate: mark other nodes as admin
- This is a site_state concern: `admin_nodes :: [binary()]` in the aggregate

### 3. Join Flow — "Let me in"

```
New Node                           Existing Site (Admin Node)
────────                           ─────────────────────────
1. Boot, discover _hecate._tcp
   on LAN via mDNS

2. UI shows: "Site 'E177...'
   found (3 nodes)"

3. User clicks "Request to Join"
   ──── join request (TLS) ──────► 4. Admin notification:
                                      "beam02 wants to join"
                                      [Approve] [Deny]

                                   5. Admin approves
   ◄── cookie (encrypted) ────────   (sends cookie via
                                      secure channel)

6. Node sets cookie, restarts
   Erlang distribution

7. Node clusters, site_store
   replicates, node auto-admits

8. Done — node appears in
   Site page on all nodes
```

### 4. Security Concerns

**Cookie exchange is the critical moment.** The cookie is the site's shared secret — possession = full cluster access.

**Threats:**

| Threat | Mitigation |
|--------|-----------|
| Eavesdropping on cookie exchange | TLS (mutual or TOFU) for the exchange channel |
| Rogue node on LAN | Approval required from admin — can't self-join |
| Replay attack | One-time join token with expiry |
| Cookie brute-force | Erlang cookies are 20+ chars, impractical |
| MitM on mDNS | mDNS is inherently LAN-trusted; admin verifies node identity visually |

**Proposed exchange mechanism:**

1. Admin generates a **join code** (6-digit, expires in 5 minutes)
2. New node enters join code in its UI
3. Code is used as a pre-shared key to establish encrypted channel
4. Cookie is transmitted over that channel
5. Join code is single-use

This is similar to Bluetooth pairing or Chromecast setup.

### 5. Provisioning UI

**On the new node (attended):**

```
┌─────────────────────────────────┐
│  Welcome to Hecate              │
│                                 │
│  Sites found on your network:   │
│                                 │
│  ┌───────────────────────────┐  │
│  │ 🏠 E177AFAB (3 nodes)    │  │
│  │   host00, beam00, beam01  │  │
│  │   [Request to Join]       │  │
│  └───────────────────────────┘  │
│                                 │
│  ── or ──                       │
│                                 │
│  [Create New Site]              │
│  [Enter Join Code]              │
│                                 │
└─────────────────────────────────┘
```

**On the admin node:**

```
┌─────────────────────────────────┐
│  Site · Join Request            │
│                                 │
│  "beam02.lab" wants to join     │
│  IP: 192.168.1.12              │
│  OS: Ubuntu 20.04              │
│                                 │
│  [Approve]  [Deny]             │
│                                 │
│  ── or ──                       │
│                                 │
│  Generate join code: [123-456]  │
│  Expires in 4:32               │
│                                 │
└─────────────────────────────────┘
```

**On a headless node (no screen):**

```bash
# Option A: join code from CLI
hecate site join --code 123-456

# Option B: pre-provisioned via env var
HECATE_SITE_JOIN_CODE=123-456

# Option C: cookie directly (for automation)
HECATE_ERLANG_COOKIE=ZMFTAHTHAYKXRVMPPQIZ
```

### 6. Implementation Phases

| Phase | What | Complexity |
|-------|------|-----------|
| **1** | site_store cluster mode (replication works) | Medium — debug ReckonDB |
| **2** | mDNS service advertisement (`_hecate._tcp`) | Low — Avahi is already enabled |
| **3** | mDNS discovery in hecate-daemon (scan for peers) | Medium |
| **4** | Join code generation + exchange protocol | High — crypto, security |
| **5** | Admin role in site aggregate | Medium |
| **6** | Provisioning UI in hecate-web | Medium — UX design |
| **7** | CLI join command for headless nodes | Low |
| **8** | Headless provisioning via env var / token | Medium |

### 7. Open Questions

1. **mDNS vs custom UDP:** Avahi/mDNS is standard and already running. Do we need custom UDP too?
2. **Node identity verification:** How does the admin know the requesting node is legitimate? IP + hostname visible, but spoofable.
3. **Cookie rotation:** If a node is removed, should the cookie change? That would disconnect all nodes.
4. **Multi-site on same LAN:** Can two sites coexist on the same LAN? Yes — different cookies, different site_ids. mDNS distinguishes by site_id in TXT record.
5. **Internet join:** Can a node join a site over the internet (not LAN)? Needs different discovery (not mDNS). Provisioning token via macula.io?
