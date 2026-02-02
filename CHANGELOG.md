# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Initial project structure
- Architecture documentation
- README with full API reference
- CLAUDE.md development guidelines
- SVG diagrams for architecture, handshake flow, install flow

### Planned
- Core Erlang application
- REST API (Cowboy)
- Macula mesh integration
- UCAN capability management
- CLI tool
- Installer script
- GitHub Actions release workflow

## [0.1.0] - TBD

Initial release.

### Features
- MRI identity generation and management
- Macula mesh connection (HTTP/3/QUIC)
- RPC client: call remote procedures
- RPC server: register local procedures
- Pub/sub: subscribe, publish, poll messages
- UCAN wallet: grant, revoke, list capabilities
- Reputation tracking: local RPC call outcomes, trust scoring
- SQLite event log
- REST API on localhost:4444
- CLI: init, start, stop, status, call, register

---

[Unreleased]: https://github.com/macula-io/macula-hecate/compare/v0.1.0...HEAD
[0.1.0]: https://github.com/macula-io/macula-hecate/releases/tag/v0.1.0
