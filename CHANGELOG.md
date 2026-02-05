# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

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

[Unreleased]: https://github.com/hecate-social/hecate-daemon/compare/v0.2.0...HEAD
[0.2.0]: https://github.com/hecate-social/hecate-daemon/compare/v0.1.3...v0.2.0
[0.1.0]: https://github.com/hecate-social/hecate-daemon/releases/tag/v0.1.0
