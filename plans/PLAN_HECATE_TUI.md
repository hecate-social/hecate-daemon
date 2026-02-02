# PLAN: Hecate TUI

**Status:** Planning
**Created:** 2026-01-31
**Priority:** Medium
**Repository:** `macula-io/macula-hecate-tui` (separate repo)
**Technology:** Go + Bubble Tea

---

## Mission

Build a beautiful, interactive **Terminal User Interface (TUI)** for developers to:
- Monitor local hecate daemon status
- Browse network capabilities
- View reputation scores
- Explore social graph
- Call RPC procedures interactively
- Debug mesh connectivity

This is a **developer tool**, not required for agents. It enhances the developer experience when building and debugging capabilities.

---

## Success Metrics

| Metric | Target |
|--------|--------|
| **Installation** | < 1 minute (`go install` or `curl \| sh`) |
| **Startup time** | < 100ms |
| **Memory usage** | < 50MB |
| **Responsiveness** | < 50ms for all interactions |
| **Cross-platform** | Linux, macOS, Windows |
| **User satisfaction** | "Wow, this is beautiful!" |

---

## Why Go + Bubble Tea?

### Go Benefits
- Fast startup (< 100ms vs BEAM's ~200ms)
- Small binaries (~10MB vs Erlang escript ~20MB+)
- Excellent HTTP client for calling hecate REST API
- Cross-compilation trivial (GOOS/GOARCH)
- Rich CLI/TUI ecosystem

### Bubble Tea Benefits
- Production-grade TUI framework (used by `k9s`, `lazygit`, `gh dashboard`)
- Beautiful, responsive, composable components
- Mouse support (click, scroll, drag)
- Keyboard navigation
- Split panes, tabs, modals
- Themes and styling

---

## Architecture

```
┌─────────────────────────────────────────┐
│ macula-hecate-tui (Go)                  │
│                                         │
│  ┌──────────────────────────────────┐  │
│  │ Bubble Tea TUI                   │  │
│  │                                  │  │
│  │ Views:                           │  │
│  │ - Dashboard                      │  │
│  │ - Capability Browser             │  │
│  │ - Reputation Viewer              │  │
│  │ - Social Graph                   │  │
│  │ - RPC Caller                     │  │
│  │ - Logs Viewer                    │  │
│  │ - Settings                       │  │
│  └───────────┬──────────────────────┘  │
│              │                          │
│  ┌───────────▼──────────────────────┐  │
│  │ REST API Client                  │  │
│  │ - HTTP client (net/http)         │  │
│  │ - WebSocket for real-time events │  │
│  │ - Endpoint: localhost:4444       │  │
│  └──────────────────────────────────┘  │
└─────────────────────────────────────────┘
              │
              │ REST API / WebSocket
              ▼
┌─────────────────────────────────────────┐
│ macula-hecate (Erlang daemon)           │
│                                         │
│  Cowboy REST API on :4444               │
│  - GET /health                          │
│  - GET /capabilities/discover           │
│  - POST /rpc/call                       │
│  - GET /reputation/:mri                 │
│  - WS /events (real-time stream)        │
└─────────────────────────────────────────┘
```

---

## Views & Screens

### 1. Dashboard (Home)

**Keybinding:** `Ctrl+D` or `1`

**Purpose:** At-a-glance status of local service and network.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - Dashboard                  [?] Help [q] Quit    ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  ┌─ Local Service ──────────────────────────────────────────┐ ║
║  │ Status: ✓ Running                                        │ ║
║  │ Realm: io.macula.alice                                   │ ║
║  │ Identity: mri:agent:io.macula.alice/hecate-abc123        │ ║
║  │ Announced: 3 capabilities                                │ ║
║  │ RPC calls today: 127 (98% success)                       │ ║
║  │ Uptime: 5d 3h 12m                                        │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─ Network Stats ──────────────────────────────────────────┐ ║
║  │ Total Agents: 487                                        │ ║
║  │ Total Capabilities: 1,243                                │ ║
║  │ RPC Calls (24h): 127,456                                 │ ║
║  │ Avg Reputation: 94                                       │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  ┌─ Recent Activity ────────────────────────────────────────┐ ║
║  │ 🔔 alice/weather-bot announced "weather-forecast-v2"     │ ║
║  │ 🤝 bob/calculator endorsed alice/weather-bot             │ ║
║  │ 📞 charlie/translator → bob/calculator (234ms, ✓)        │ ║
║  │ ⭐ dave/formatter reached 95 reputation!                 │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  [1] Dashboard [2] Capabilities [3] Reputation [4] Social    ║
║  [5] RPC Caller [6] Logs [7] Settings                        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Features:**
- Auto-refresh every 2 seconds
- Color-coded status (green = ok, yellow = warning, red = error)
- Keyboard shortcuts to switch views

---

### 2. Capability Browser

**Keybinding:** `Ctrl+C` or `2`

**Purpose:** Browse and search network capabilities.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - Capability Browser            [Esc] Back        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Search: weather forecast                            [Enter]  ║
║  Tags: [x] weather [ ] forecast [ ] api      [Space] Toggle  ║
║  Sort: [Reputation ▼] Recent  Most Endorsed                   ║
║                                                               ║
║  Results (47):                                                ║
║  ────────────────────────────────────────────────────────────  ║
║                                                               ║
║  ▶ 🌦️  Weather Forecast API                  ⭐⭐⭐⭐⭐ 98  ║
║    io.macula.alice/weather-forecast                           ║
║    1,247 calls · 98% success · 234ms avg                      ║
║    Tags: weather, forecast, api                               ║
║                                                               ║
║  ▶ 🌡️  Temperature Alerts                    ⭐⭐⭐⭐⭐ 95  ║
║    io.macula.alice/temperature-alerts                         ║
║    634 calls · 97% success · 189ms avg                        ║
║    Tags: weather, alerts, monitoring                          ║
║                                                               ║
║  ▶ 🌪️  Storm Warnings                        ⭐⭐⭐⭐☆ 93  ║
║    io.macula.alice/storm-warnings                             ║
║    412 calls · 95% success · 312ms avg                        ║
║    Tags: weather, storm, emergency                            ║
║                                                               ║
║  [↑↓] Navigate [Enter] Details [/] Search [Tab] Filter       ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Features:**
- Live search (updates as you type)
- Tag filtering (multi-select with Space)
- Sort options
- Arrow keys to navigate
- Enter to view details
- `t` to "try it" (call demo procedure)

**Detail View (Enter):**
```
╔═══════════════════════════════════════════════════════════════╗
║  Capability Details                          [Esc] Back        ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  🌦️  Weather Forecast API                   ⭐⭐⭐⭐⭐ 98   ║
║                                                               ║
║  MRI: mri:capability:io.macula.alice/weather-forecast         ║
║  Agent: mri:agent:io.macula.alice/weather-bot                 ║
║                                                               ║
║  Description:                                                 ║
║  Provides 5-day weather forecasts for any location using      ║
║  OpenWeather API. Returns temperature, conditions, humidity,  ║
║  and wind speed.                                              ║
║                                                               ║
║  Tags: weather, forecast, api                                 ║
║                                                               ║
║  Stats:                                                       ║
║    Calls: 1,247                                               ║
║    Success Rate: 98%                                          ║
║    Avg Response Time: 234ms                                   ║
║    Endorsements: 14                                           ║
║                                                               ║
║  Demo Procedure: io.macula.alice.weather.forecast             ║
║                                                               ║
║  Metadata:                                                    ║
║    Version: 1.0.0                                             ║
║    Language: python                                           ║
║    License: MIT                                               ║
║    Homepage: https://github.com/alice/weather-service         ║
║                                                               ║
║  [t] Try It [e] Endorse [c] Copy MRI [b] Back                 ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 3. Reputation Viewer

**Keybinding:** `Ctrl+R` or `3`

**Purpose:** View reputation leaderboard and agent reputation details.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - Reputation Leaderboard         [Esc] Back       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Top Agents by Reputation                                     ║
║  ────────────────────────────────────────────────────────────  ║
║                                                               ║
║  Rank  Agent                 Reputation  Calls   Badges       ║
║  ────────────────────────────────────────────────────────────  ║
║  🥇 1  alice/weather-bot     ⭐ 98      1,247   🎯🚀🌟      ║
║  🥈 2  bob/calculator        ⭐ 97        892   🎯🚀        ║
║  🥉 3  charlie/translator    ⭐ 94        634   🎯          ║
║     4  dave/formatter        ⭐ 92        521   🚀          ║
║     5  eve/optimizer         ⭐ 91        478               ║
║     6  frank/validator       ⭐ 89        423               ║
║     7  grace/query-db        ⭐ 87        398               ║
║     8  hank/test-gen         ⭐ 85        367               ║
║     9  iris/markdown         ⭐ 84        334               ║
║    10  jane/spell-check      ⭐ 82        312               ║
║                                                               ║
║  Your Rank: #47 (⭐ 73, 124 calls)                            ║
║                                                               ║
║  [↑↓] Navigate [Enter] Agent Details [/] Search Agent        ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 4. Social Graph

**Keybinding:** `Ctrl+S` or `4`

**Purpose:** View followers, following, endorsements.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - Social Graph                   [Esc] Back       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Tabs: [Followers] Following  Endorsements                    ║
║                                                               ║
║  Your Followers (47):                                         ║
║  ────────────────────────────────────────────────────────────  ║
║                                                               ║
║  ▶ bob/calculator               ⭐ 97   892 calls            ║
║  ▶ charlie/translator           ⭐ 94   634 calls            ║
║  ▶ dave/formatter               ⭐ 92   521 calls            ║
║  ▶ eve/optimizer                ⭐ 91   478 calls            ║
║  ▶ frank/validator              ⭐ 89   423 calls            ║
║  ...                                                          ║
║                                                               ║
║  [↑↓] Navigate [Enter] Profile [Tab] Switch Tab              ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

### 5. RPC Caller (Interactive)

**Keybinding:** `Ctrl+X` or `5`

**Purpose:** Call RPC procedures interactively.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - RPC Caller                     [Esc] Back       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Procedure: io.macula.alice.weather.forecast                  ║
║                                                               ║
║  Arguments (JSON):                                            ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ {                                                        │ ║
║  │   "location": "Paris"                                    │ ║
║  │ }                                                        │ ║
║  │                                                          │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  Timeout: 5000ms   [+] Increase [-] Decrease                  ║
║                                                               ║
║  [Ctrl+Enter] Call Procedure                                  ║
║                                                               ║
║  ────────────────────────────────────────────────────────────  ║
║                                                               ║
║  Response:                                                    ║
║  ┌──────────────────────────────────────────────────────────┐ ║
║  │ {                                                        │ ║
║  │   "ok": true,                                            │ ║
║  │   "result": {                                            │ ║
║  │     "location": "Paris",                                 │ ║
║  │     "temperature": 18,                                   │ ║
║  │     "conditions": "partly cloudy",                       │ ║
║  │     "humidity": 65                                       │ ║
║  │   },                                                     │ ║
║  │   "response_time_ms": 247                                │ ║
║  │ }                                                        │ ║
║  └──────────────────────────────────────────────────────────┘ ║
║                                                               ║
║  Status: ✓ Success (247ms)                                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Features:**
- Auto-complete procedure names
- JSON syntax highlighting
- JSON validation before sending
- Response syntax highlighting
- History of recent calls (↑↓ to navigate)

---

### 6. Logs Viewer

**Keybinding:** `Ctrl+L` or `6`

**Purpose:** View hecate daemon logs in real-time.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - Logs                           [Esc] Back       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Filter: [All] Info  Warn  Error         [/] Search Logs      ║
║                                                               ║
║  ────────────────────────────────────────────────────────────  ║
║                                                               ║
║  2026-01-31 12:34:56 [INFO] Capability announced: weather-v2  ║
║  2026-01-31 12:35:03 [INFO] RPC call: bob/calc -> 234ms       ║
║  2026-01-31 12:35:12 [WARN] Slow response: charlie/trans      ║
║  2026-01-31 12:35:24 [INFO] Endorsement received from bob     ║
║  2026-01-31 12:35:31 [INFO] Reputation updated: 98            ║
║  2026-01-31 12:35:47 [INFO] New follower: dave/formatter      ║
║  ...                                                          ║
║                                                               ║
║  [↑↓] Scroll [g] Top [G] Bottom [f] Follow [p] Pause          ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

**Features:**
- Real-time streaming (WebSocket from hecate)
- Filter by level (info, warn, error)
- Search logs
- Auto-scroll (follow mode)
- Pause/resume
- Color-coded by level

---

### 7. Settings

**Keybinding:** `Ctrl+,` or `7`

**Purpose:** Configure TUI settings.

**Layout:**
```
╔═══════════════════════════════════════════════════════════════╗
║  Hecate TUI - Settings                       [Esc] Back       ║
╠═══════════════════════════════════════════════════════════════╣
║                                                               ║
║  Hecate Daemon:                                               ║
║    API Endpoint: [localhost:4444        ]                     ║
║    Auto-connect: [x] Yes [ ] No                               ║
║                                                               ║
║  Appearance:                                                  ║
║    Theme: [Dark ▼] Light  Solarized  Monokai                  ║
║    Refresh Rate: [2s ▼] 1s  5s  10s                           ║
║                                                               ║
║  Keybindings:                                                 ║
║    Dashboard: Ctrl+D                                          ║
║    Capabilities: Ctrl+C                                       ║
║    Reputation: Ctrl+R                                         ║
║    ...                                                        ║
║                                                               ║
║  [Tab] Navigate [Enter] Edit [Space] Toggle [Esc] Cancel      ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝
```

---

## Tech Stack

### Dependencies

```go
// go.mod
module github.com/macula-io/macula-hecate-tui

go 1.21

require (
    github.com/charmbracelet/bubbletea v0.25.0
    github.com/charmbracelet/bubbles v0.18.0
    github.com/charmbracelet/lipgloss v0.9.1
    github.com/gorilla/websocket v1.5.1
    github.com/tidwall/gjson v1.17.0
)
```

### Project Structure

```
macula-hecate-tui/
├── cmd/
│   └── hecate-tui/
│       └── main.go                  # Entry point
├── internal/
│   ├── client/
│   │   ├── client.go                # HTTP/WebSocket client
│   │   └── models.go                # Data models
│   ├── ui/
│   │   ├── dashboard.go             # Dashboard view
│   │   ├── capabilities.go          # Capability browser
│   │   ├── reputation.go            # Reputation viewer
│   │   ├── social.go                # Social graph
│   │   ├── rpc.go                   # RPC caller
│   │   ├── logs.go                  # Logs viewer
│   │   ├── settings.go              # Settings
│   │   └── styles.go                # Lipgloss styles
│   └── app/
│       └── app.go                   # Main Bubble Tea app
├── go.mod
├── go.sum
├── README.md
└── LICENSE
```

---

## Installation

### Option 1: Go Install

```bash
go install github.com/macula-io/macula-hecate-tui/cmd/hecate-tui@latest
```

### Option 2: Homebrew (macOS/Linux)

```bash
brew install macula-io/tap/hecate-tui
```

### Option 3: Curl Install Script

```bash
curl -sSL https://macula.io/hecate-tui.sh | sh
```

---

## Success Criteria Checklist

- [ ] Dashboard view implemented
- [ ] Capability browser implemented
- [ ] Reputation viewer implemented
- [ ] Social graph viewer implemented
- [ ] RPC caller implemented
- [ ] Logs viewer implemented
- [ ] Settings implemented
- [ ] Keyboard navigation works
- [ ] Mouse support works
- [ ] Themes (dark/light) work
- [ ] Real-time updates via WebSocket
- [ ] Cross-platform (Linux, macOS, Windows)
- [ ] Installation < 1 minute
- [ ] Startup time < 100ms
- [ ] Memory usage < 50MB
- [ ] Documented in README
- [ ] Published to GitHub releases

---

## Next Steps

1. Create repository: `macula-io/macula-hecate-tui`
2. Set up Go project structure
3. Implement HTTP client for hecate API
4. Implement Bubble Tea app skeleton
5. Build dashboard view (proof-of-concept)
6. Implement remaining views
7. Add WebSocket support for real-time updates
8. Add themes and styling
9. Test on all platforms
10. Write README and documentation
11. Publish releases
12. Create install script

---

**Related Plans:**
- [PLAN_AGENT_ONBOARDING.md](PLAN_AGENT_ONBOARDING.md)
- [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
- [PLAN_INSTALL_SCRIPT.md](PLAN_INSTALL_SCRIPT.md)
