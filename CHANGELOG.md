# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed
- **Renamed pairing to joining** — all "pairing" terminology replaced with "joining
  a realm". `hecate pair` CLI command is now `hecate join`. Confirm code removed —
  OAuth login is sufficient proof of intent since the browser opens from the same
  device. API endpoints changed from `/api/v1/pairing/sessions` to
  `/api/v1/join/sessions`. `hecate_realm_session` state no longer carries
  `confirm_code`.

### Ideas
- **Settings history widget** — expose the settings event stream as a timeline
  on the settings page. A way to visualize our event-sourced nature: every
  initiation, realm joining, and preference change shown chronologically.
  Needs a new query desk (e.g. `get_settings_history/`) that reads from the
  settings ReckonDB stream and returns the event log.

## [0.11.2] - 2026-02-26

### Fixed
- **Container hostname/user detection** — inside a podman container,
  `os:cmd("whoami")` returns `root` and `net_adm:localhost()` returns the
  container hostname. New `shared_host` module checks `HECATE_HOSTNAME` and
  `HECATE_USER` env vars first (set by systemd specifiers `%H`/`%u` in the
  Quadlet container file), falling back to OS detection
- **Pairing URL includes confirmation code** — pairing URL now appends
  `?code={confirm_code}` so the realm page can auto-confirm without manual
  code entry
- **Agent info version hardcoded at 0.1.0** — now reads from app vsn

## [0.11.1] - 2026-02-26

### Fixed
- **Node identity auto-initializes on first boot** — no more "Run `hecate init`"
  message. The daemon generates an Ed25519 keypair and MRI automatically when
  no existing identity is found, matching the existing `auto_initiate_settings`
  pattern

## [0.11.0] - 2026-02-26

### Changed
- **Subscription architecture overhaul** — all 30 projections, emitters, and
  process managers migrated from `reckon_evoq_adapter:subscribe/5` to
  `evoq_subscriptions:subscribe/5` facade (evoq 1.4.0)
- Upgrade evoq to 1.4.0 (new `evoq_subscriptions` facade module)
- Upgrade reckon_evoq to 1.2.0 (subscription bridge: translates ReckonDB
  `{events, [#event{}]}` into `{events, [#evoq_event{}]}`)
- `projection_event:to_map/1` now handles both `#evoq_event{}` and `#event{}`
  records (bridge sends evoq events)

### Fixed
- **Settings initiation broken on Arch Linux** — `os:cmd("hostname -s")` fails
  when `hostname` binary doesn't exist, corrupting stream IDs and preventing
  settings from being created. Replaced with `net_adm:localhost()` in both
  `settings_aggregate:stream_id/0` and `guide_settings_lifecycle_app`
- `project_llm_mentorships_subscriber` expected `{event, #evoq_event{}}` but
  ReckonDB bridge sends `{events, [#evoq_event{}]}` — fixed message pattern
  and event routing

## [0.10.3] - 2026-02-25

### Fixed
- `settings_aggregate` missing `apply/2` callback and `-behaviour(evoq_aggregate).`
  declaration — caused `{undef, [{settings_aggregate,apply,...}]}` crash when
  applying events after command execution. The missing behaviour declaration
  meant the compiler never warned about the missing callback. All other
  aggregates correctly declare the behaviour.

## [0.10.2] - 2026-02-25

### Fixed
- `settings_aggregate` missing `init/1` callback required by evoq — caused
  `{undef, [{settings_aggregate,init,...}]}` crash on every command dispatch,
  preventing settings auto-initiation from completing

## [0.10.1] - 2026-02-25

### Fixed
- Settings auto-initiation timing race — replaced 500ms blind delay with
  explicit wait for `settings_initiated_v1_to_settings` projection process,
  ensuring the event is projected into SQLite before queries arrive
- Health endpoint version was hardcoded at `0.1.0` — now reads from app vsn
- Release version in `rebar.config` was stale at `0.9.2`

## [0.10.0] - 2026-02-25

### Added
- `GET /api/node/identity` — returns MRI, Ed25519 public key, realm from `hecate_identity`
- `POST /api/pairing/initiate` — starts OAuth pairing session via `hecate_pairing`
- `GET /api/pairing/status` — polls current pairing session status
- `POST /api/pairing/cancel` — cancels active pairing session
- API handler tests for settings, node identity, and pairing endpoints (19 tests)

### Changed
- `GET /api/settings` response reshaped from flat `{settings: {...}}` to structured `{identity: {...}, preferences: {...}}`

## [0.9.2] - 2026-02-25

### Removed
- `hecate_api_agents` (stub returning empty lists)
- `hecate_api_identity` (duplicate of `query_settings/get_identity_api`)
- `hecate_api_pairing` (superseded by `guide_settings_lifecycle` handlers)
- `auto_register_default_connector` dead code and `guide_node_lifecycle` config
- `hecate_telemetry` app (broken — dissolved into `serve_llm`)

### Changed
- Moved geo API handler to `geo_check` app (`geo_check_api`)
- Moved RPC call handler to `hecate_mesh` app (`call_rpc/call_rpc_api`)
- Moved sidebar config to `guide_settings_lifecycle` app (`configure_sidebar/` desk)
- Rebuilt LLM usage tracking as `serve_llm/track_llm_usage/` desk (llm_pricing, llm_usage_store, track_llm_usage_api)
- Fixed `chat_to_llm` terminology: `torch_id`/`cartwheel_id` → `venture_id`/`division_id`
- Replaced `io:format` with `logger` in `hecate_mesh` app
- Removed `jsx` dep and legacy aliases from `hecate_mesh`
- Stripped domain app dependencies from `hecate_api` (now infrastructure-only)

## [0.9.1] - 2026-02-25

### Changed
- Split shared `hecate_event_store` into domain-specific stores: `settings_store`, `llm_store`, `mentorships_store`
- Refactored `hecate_app.erl` store startup into single `start_stores/1` loop

### Removed
- `dev_studio_store` (dead — venture lifecycle moved to Martha)

## [0.9.0] - 2026-02-25

### Added
- License lifecycle domain (guide_license_lifecycle, project_licenses, query_licenses) — folded from hecate-app-appstored
- Plugin lifecycle domain (guide_plugin_lifecycle, project_plugins, query_plugins) — folded from hecate-app-noded
- Dedicated ReckonDB stores: licenses_store, plugins_store
- `shared_paths:gitops_apps_dir/0` for plugin container provisioning

### Removed
- 12 ghost app directories extracted to standalone repos (Martha, IRC, Snake Duel, Snake Gladiators) or dead code (node/venture lifecycle)

### Changed
- License mesh publishing uses direct `hecate_mesh:publish/2` (removed appstored mesh proxy indirection)

## [0.8.2] - 2026-02-21

### Fixed
- Upgrade reckon_db to 1.3.2 (supervised pg scope — fixes silent event delivery failure)

## [0.8.1] - 2026-02-18

### Fixed
- Upgrade reckon_db to 1.2.7 (fixes `{badmap, undefined}` crash in persistence worker)

### Added
- Snake Gladiators: neuroevolution training with LTC/CfC neurons, 22 sensors, multi-champion breeding
- Snake Gladiators: drop tail ability, champion duels, configurable fitness weights
- Snake Duel: real-time arena with match lifecycle
- IRC: channel members endpoint, members_changed SSE, auto-close empty channels
- Big Picture Event Storming with 17 command desks
- Batch test endpoint for headless champion duels
- Two-phase socket startup + daemon lifecycle state files

### Changed
- Migrate to namespaced directory layout `~/.hecate/hecate-daemon/`
- Consolidate 30 apps into 8 + add 582 tests
- Emitters and projections subscribe via evoq (not direct ReckonDB)
- Route auto-discovery: handlers export `routes/0` instead of centralized route files
- Verticalize route definitions: each domain app owns its routes

## [0.8.0] - 2026-02-10

### Added
- **Venture Lifecycle Architecture**: 10 process apps replacing torch/cartwheel
  - setup_venture, discover_divisions, design_division, plan_division
  - generate_division, test_division, deploy_division, monitor_division, rescue_division
  - guide_venture (orchestrator)
- Corresponding query apps: query_ventures, query_discoveries, query_designs, query_plans, query_generations
- 4-layer testing strategy (265+ tests across all venture lifecycle apps)
- TUI fact-driven side effects and archive torch spoke
- Refine/submit vision spokes for Discovery & Analysis workflow
- evoq_bit_flags across all 7 aggregates with status_label enrichment

### Changed
- Kill god modules, standardize routes to `/api/` prefix
- Auto-detect `GEMINI_API_KEY` as fallback for Google provider

### Removed
- Legacy torch/cartwheel apps (replaced by venture lifecycle)

## [0.7.4] - 2026-02-09

### Fixed
- Ensure pg scope exists before joining group

## [0.7.3] - 2026-02-09

### Fixed
- Use pg for internal cartwheel_identified integration (not direct dispatch)
- Use correct OTP pg API with scope
- Auto-create SQLite tables on store startup
- Use correct evoq config key `event_store_adapter`

### Added
- Wire torch events to ReckonDB via evoq
- Project events to read model after dispatch

## [0.7.2] - 2026-02-08

### Changed
- Use native arm64 runners instead of QEMU emulation for CI

## [0.7.1] - 2026-02-08

### Fixed
- Correct esqlite3:prepare argument order (Db, Sql)

## [0.7.0] - 2026-02-08

### Added
- Unix socket listener support with configurable `HECATE_SOCKET_PATH`
- Auto-detect commercial LLM providers from env vars (Anthropic, OpenAI, Google, Groq)
- Tool/function calling support for Google and Ollama providers
- Geographic restriction system (geo_check app)
- Parent-child aggregate pattern (Torch -> Cartwheel)
- Process Manager for torch -> cartwheel integration
- Walking Skeleton daemon infrastructure (Phases 1-7)

### Changed
- Socket-only access with 0660 permissions (removed TCP 4444)
- Vertical API handlers: spokes own their HTTP handlers

### Fixed
- SSE timeout increased to 5 minutes for large models
- Ollama timeout increased for large model loading
- Google provider tool schema handling for Gemini
- Binary keys in provider chunk messages
- json:encode iolist to binary conversion for stream_body

## [0.6.0] - 2026-02-06

### Changed
- Upgrade reckon-db stack for subscription type fix

## [0.5.0] - 2026-02-06

### Added
- Tool support for LLM providers and RPC call endpoint

### Fixed
- Correct esqlite3:exec argument order in query_mentors and query_alc stores
- Correct macula:subscribe API and defer listener subscriptions
- Use event_type subscriptions instead of unsupported 'all'
- Add missing hecate_identity:agent_id/0 and qrcode app dependency
- Resolve CI build failures (duplicated modules and adapter arity mismatches)

## [0.4.0] - 2026-02-05

### Added
- Multi-provider LLM support (OpenAI, Anthropic, Google)

## [0.3.0] - 2026-02-05

### Added
- ALC domain: full Application Lifecycle with 4 phases (design, plan, generate, test)

## [0.2.0] - 2026-02-05

### Added
- **mentor_agents** command service: decentralized agent learning domain
  - 3 aggregates: learning, mentor_profile, mentor_subscription
  - 10 spokes: submit/validate/reject/endorse/dispute/resolve learnings, declare/withdraw expertise, subscribe/unsubscribe mentors
  - 4 mesh emitters: validated learnings, endorsed learnings, expertise declared/withdrawn
  - Bit flag status fields on all aggregates
- **query_mentors** query service: SQLite read models for mentor/learning data
  - 10 projections from domain events
  - 6 query modules: find_learning, list_learnings, list_mentors, get_mentor_profile, list_subscriptions, list_remote_learnings
  - 2 mesh listener spokes: remote_learning_listener, mentor_discovery_listener
  - 5 SQLite tables: learnings, mentor_subscriptions, mentor_profiles, remote_learnings, remote_mentors
- **manage_connectors** command service: Unix socket connector lifecycle
  - Connector aggregate with bit flag status (REGISTERED, ACTIVE, SUSPENDED, REVOKED)
  - register/activate/suspend/revoke connector spokes
  - Route scoping middleware
  - Process manager: auto-start listener on connector registration
- **hecate_api_mentors**: 16 REST endpoints under /mentors/
- **hecate_api_connectors**: 4 REST endpoints under /connectors/

## [0.1.0] - 2026-02-02

### Features
- MRI identity generation and management
- Macula mesh connection (HTTP/3/QUIC)
- RPC client: call remote procedures
- RPC server: register local procedures
- Pub/sub: subscribe, publish, poll messages
- UCAN wallet: grant, revoke, list capabilities
- Reputation tracking: local RPC call outcomes, trust scoring
- Event sourcing with embedded ReckonDB
- CQRS architecture with vertical slicing
- Capability management (announce/update/retract)
- Social graph (follow/unfollow/endorse)
- Identity management (register/update agents)
- Subscription management
- LLM capability service (Ollama integration)
- REST API on localhost:4444
- Rich metadata, UCAN validation, latency measurement

---

[Unreleased]: https://github.com/hecate-social/hecate-daemon/compare/v0.11.2...HEAD
[0.11.2]: https://github.com/hecate-social/hecate-daemon/compare/v0.11.1...v0.11.2
[0.11.1]: https://github.com/hecate-social/hecate-daemon/compare/v0.11.0...v0.11.1
[0.11.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.10.3...v0.11.0
[0.10.3]: https://github.com/hecate-social/hecate-daemon/compare/v0.10.2...v0.10.3
[0.10.2]: https://github.com/hecate-social/hecate-daemon/compare/v0.10.1...v0.10.2
[0.10.1]: https://github.com/hecate-social/hecate-daemon/compare/v0.10.0...v0.10.1
[0.10.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.9.2...v0.10.0
[0.9.2]: https://github.com/hecate-social/hecate-daemon/compare/v0.9.1...v0.9.2
[0.9.1]: https://github.com/hecate-social/hecate-daemon/compare/v0.9.0...v0.9.1
[0.9.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.8.2...v0.9.0
[0.8.2]: https://github.com/hecate-social/hecate-daemon/compare/v0.8.1...v0.8.2
[0.8.1]: https://github.com/hecate-social/hecate-daemon/compare/v0.8.0...v0.8.1
[0.8.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.7.4...v0.8.0
[0.7.4]: https://github.com/hecate-social/hecate-daemon/compare/v0.7.3...v0.7.4
[0.7.3]: https://github.com/hecate-social/hecate-daemon/compare/v0.7.2...v0.7.3
[0.7.2]: https://github.com/hecate-social/hecate-daemon/compare/v0.7.1...v0.7.2
[0.7.1]: https://github.com/hecate-social/hecate-daemon/compare/v0.7.0...v0.7.1
[0.7.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.6.0...v0.7.0
[0.6.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.5.0...v0.6.0
[0.5.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.4.0...v0.5.0
[0.4.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.3.0...v0.4.0
[0.3.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.2.0...v0.3.0
[0.2.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.1.3...v0.2.0
[0.1.0]: https://github.com/hecate-social/hecate-daemon/releases/tag/v0.1.0
