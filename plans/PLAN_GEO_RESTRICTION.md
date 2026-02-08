# Plan: Hecate Geo-Restriction System

## Status: ✅ COMPLETE

Multi-layer geographic access control for the Hecate ecosystem.

**Completed:** 2026-02-08

---

## Implementation Summary

All 4 layers of geo-restriction have been implemented and deployed:

| Layer | Repository | Commit | Status |
|-------|------------|--------|--------|
| 1. Bootstrap | `macula-io/macula-boot` | `c730324` | ✅ Pushed |
| 2. Realm | `macula-io/macula-realm` | `72a2019` | ✅ Pushed |
| 3. Daemon | `hecate-social/hecate-daemon` | (previous session) | ✅ Pushed |
| 4. TUI | `hecate-social/hecate-tui` | (previous session) | ✅ Pushed |

---

## Overview

Geo-restriction across all Hecate components to control which countries can access the service. Defense-in-depth approach with checks at multiple layers.

**Goal:** Even local-only usage is restricted for blocked countries.

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         GEO-RESTRICTION LAYERS                       │
├─────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  Layer 1: BOOTSTRAP (macula-boot) ✅                                 │
│  ├── Health server returns 403 for blocked regions                   │
│  └── /health and /ready exempt (k8s probes)                          │
│                                                                       │
│  Layer 2: REALM (macula-realm) ✅                                    │
│  ├── API pipeline geo-checks all /api/v1 routes                      │
│  └── OAuth callback validates location                               │
│                                                                       │
│  Layer 3: DAEMON (hecate-daemon) ✅                                  │
│  ├── Startup geo-check before mesh connection                        │
│  ├── Periodic re-validation worker (hourly)                          │
│  └── /api/geo/status endpoint for TUI                                │
│                                                                       │
│  Layer 4: TUI (hecate-tui) ✅                                        │
│  ├── Startup geo-check before daemon connection                      │
│  ├── Clear error messaging for blocked users                         │
│  └── /geo command for manual status check                            │
│                                                                       │
└─────────────────────────────────────────────────────────────────────┘
```

---

## Configuration

All layers use consistent environment variables:

| Variable | Description | Default |
|----------|-------------|---------|
| `MACULA_GEO_MODE` | `blocklist` or `allowlist` | `blocklist` |
| `MACULA_GEO_BLOCKED_COUNTRIES` | Comma-separated ISO codes | `RU,CN,KP,IR,BY` |
| `MACULA_GEO_ALLOWED_COUNTRIES` | For allowlist mode | (empty) |
| `MACULA_GEO_DB_PATH` | Custom GeoLite2-Country.mmdb path | auto-detect |

### Default Blocked Countries
- RU - Russia
- CN - China
- KP - North Korea
- IR - Iran
- BY - Belarus

### Private IP Ranges (Always Allowed)
- 127.0.0.0/8 (localhost)
- 10.0.0.0/8 (private)
- 172.16.0.0/12 (private)
- 192.168.0.0/16 (private)

---

## Files Created/Modified

### macula-boot (Elixir)

| File | Description | Status |
|------|-------------|--------|
| `lib/macula_boot/geo.ex` | GeoIP lookup module | ✅ Created |
| `lib/macula_boot/application.ex` | Init geo database on startup | ✅ Modified |
| `lib/macula_boot/health_server.ex` | 403 response for blocked IPs | ✅ Modified |
| `mix.exs` | Added geolix dependencies | ✅ Modified |

### macula-realm (Elixir/Phoenix)

| File | Description | Status |
|------|-------------|--------|
| `apps/macula_realm/lib/macula_realm/geo.ex` | GeoIP lookup module | ✅ Created |
| `apps/macula_realm/lib/macula_realm/application.ex` | Init geo database | ✅ Modified |
| `apps/macula_realm_web/lib/macula_realm_web/plugs/geo_restrict.ex` | Geo restriction plug | ✅ Created |
| `apps/macula_realm_web/lib/macula_realm_web/router.ex` | Applied to API + auth | ✅ Modified |
| `apps/macula_realm/mix.exs` | Added geolix dependencies | ✅ Modified |

### hecate-daemon (Erlang)

| File | Description | Status |
|------|-------------|--------|
| `apps/geo_check/src/geo_check.erl` | Main geo-check module | ✅ Created |
| `apps/geo_check/src/geo_check_config.erl` | Config loading (YAML) | ✅ Created |
| `apps/geo_check/src/geo_check_worker.erl` | Periodic re-validation | ✅ Created |
| `apps/geo_check/src/geo_check_app.erl` | Application module | ✅ Created |
| `apps/geo_check/src/geo_check_sup.erl` | Supervisor | ✅ Created |
| `apps/hecate_mesh/src/hecate_mesh_app.erl` | Startup check | ✅ Modified |
| `apps/hecate_api/src/hecate_api_geo.erl` | Geo status endpoint | ✅ Created |
| `apps/hecate_api/src/hecate_api_router.erl` | Add routes | ✅ Modified |
| `config/geo_restrictions.yaml` | Configuration file | ✅ Created |

### hecate-tui (Go)

| File | Description | Status |
|------|-------------|--------|
| `internal/geo/check.go` | GeoIP checker | ✅ Created |
| `internal/geo/types.go` | Type definitions | ✅ Created |
| `internal/ui/geo_blocked.go` | Blocked UI component | ✅ Created |
| `internal/commands/geo.go` | /geo command | ✅ Created |
| `cmd/hecate-tui/main.go` | Startup check | ✅ Modified |

---

## Dependencies

### Elixir (macula-boot, macula-realm)
```elixir
{:geolix, "~> 2.0"},
{:geolix_adapter_mmdb2, "~> 0.6"}
```

### Erlang (hecate-daemon)
```erlang
{locus, "~> 2.3"}
```

### Go (hecate-tui)
```go
require github.com/oschwald/geoip2-golang v1.9.0
```

---

## Verification Commands

```bash
# Test with VPN set to blocked country (e.g., RU)

# 1. macula-boot
curl https://boot.macula.io/health
# Expected: 403 {"error": "geo_restricted", "country": "RU"}

# 2. macula-realm
curl -X POST https://realm.macula.io/api/v1/auth/verify
# Expected: 403 geo_restricted

# 3. hecate-daemon
./hecate-daemon start
# Expected: Exit with ACCESS RESTRICTED message

# 4. hecate-tui
./hecate-tui
# Expected: "ACCESS RESTRICTED" UI, exit code 1

# Check geo status via daemon API
curl --unix-socket /run/hecate/daemon.sock http://localhost/api/geo/status
```

---

## Future Enhancements (Not Implemented)

1. **VPN/Proxy Detection** - IP reputation databases, behavioral heuristics
2. **Signed Configurations** - Ed25519 signed geo config files
3. **GeoIP Database Updates** - Weekly cron job for MaxMind updates
4. **Admin Interface** - Web UI for country list management
5. **Monitoring/Alerting** - Track geo-block patterns

---

## Open Questions (Deferred)

1. **Legal considerations**: Export control requirements for specific countries
2. **Appeals process**: How do legitimate users in blocked regions request access?
3. **Enterprise exceptions**: Do enterprise customers get whitelisting capability?
4. **Monitoring**: How do we track/alert on geo-block patterns?
