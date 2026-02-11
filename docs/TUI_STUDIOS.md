# TUI Studios — UX Specification

v1 screen designs and commands for all built-in Hecate TUI studios.

---

## Studio Switcher

### Home Screen (first launch)

```
╭───────────────────────────────────────────────────────────────╮
│                                                               │
│                         H E C A T E                          │
│                                                               │
│      ┌───────────┐  ┌───────────┐  ┌───────────┐            │
│      │  1. LLM   │  │  2. Dev   │  │  3. Ops   │            │
│      │  Chat AI  │  │  Ventures │  │  Node Mgmt│            │
│      └───────────┘  └───────────┘  └───────────┘            │
│      ┌───────────┐  ┌───────────┐                            │
│      │ 4. Social │  │ 5. Arcade │                            │
│      │  Chat IRC │  │   Games   │                            │
│      └───────────┘  └───────────┘                            │
│                                                               │
│                    beam00  ● healthy                          │
├───────────────────────────────────────────────────────────────┤
│ Press 1-5 to enter a studio                                  │
╰───────────────────────────────────────────────────────────────╯
```

Shown on first launch. Subsequent launches open the last-used studio directly.

### Top Bar (during use)

```
│  ● LLM    ○ Dev    ○ Ops    ○ Social    ○ Arcade             │
```

- Active studio is highlighted (bold/inverted), others dimmed
- `Ctrl+1-5` switches studios in Normal mode
- `/studio` command lists studios, `/studio <name>` switches
- Each studio preserves its full state when switching away and back

### Common Layout

All studios share the same frame:

```
╭───────────────────────────────────────────────────────────────╮
│  Studio top bar                                              │
├───────────────────────────────────────────────────────────────┤
│  Content area (studio-specific)                              │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > Input area                                                  │
├───────────────────────────────────────────────────────────────┤
│  Status bar (contextual per studio)                          │
├───────────────────────────────────────────────────────────────┤
│  Hints bar (available commands)                              │
╰───────────────────────────────────────────────────────────────╯
```

The input area is always present, always works the same way (Insert mode to type, Normal mode for navigation). What changes is context — AI, AI-in-context, humans, or game input.

---

## 1. LLM Studio

Free-form AI chat. This is what exists today, reframed as a studio.

### Main View

```
╭───────────────────────────────────────────────────────────────╮
│  ● LLM    ○ Dev    ○ Ops    ○ Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  You:                                                        │
│  How should I structure a REST API for weather data?         │
│                                                               │
│  Hecate:                                                     │
│  I'd suggest three endpoints organized by resource:          │
│                                                               │
│    GET  /forecasts/:location                                 │
│    GET  /observations/:station                               │
│    POST /alerts/subscribe                                    │
│                                                               │
│  Each returns JSON with consistent envelope...               │
│                                                               │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [I]     │
├───────────────────────────────────────────────────────────────┤
│ /model  /roles  /fn on|off  /clear  Ctrl+1-5: studios        │
╰───────────────────────────────────────────────────────────────╯
```

### Commands

| Command | What |
|---------|------|
| `/model` | Switch LLM model |
| `/roles` | Switch AI persona (DnA, AnP, TnI, DnO) |
| `/fn on\|off` | Toggle tool/function calling |
| `/clear` | Clear chat history |

### Notes

- Already functional — only change is adding studio top bar
- Personality system (PERSONALITY.md + roles) already implemented
- Chat history (up/down arrows) already implemented

---

## 2. Development Studio

AI-guided venture lifecycle. v1 supports all 10 processes, starting with setup + discover.

### Main View (no active ventures)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ● Dev    ○ Ops    ○ Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Ventures                                                    │
│  ─────────────────────────────────────────────────────       │
│  No active ventures.                                         │
│                                                               │
│  Start your first venture:                                   │
│                                                               │
│    /venture new         Create a new venture                 │
│    /venture list        List all ventures                    │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [I]     │
├───────────────────────────────────────────────────────────────┤
│ /venture new  /venture list  Ctrl+1-5: studios               │
╰───────────────────────────────────────────────────────────────╯
```

### Main View (with ventures)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ● Dev    ○ Ops    ○ Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Ventures                                                    │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  ● weather-api           Setup ✓  Discovery ◐               │
│    "REST API for weather data"                               │
│    2 divisions discovered, 1 pending                         │
│                                                               │
│  ○ hecate-plugins        Setup ◐                             │
│    "Plugin system for Hecate TUI"                            │
│                                                               │
│  ○ home-automation       Setup ✓  Discovery ✓  Design ◐     │
│    "Smart home controller"                                   │
│    4 divisions, designing api-gateway                        │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [I]     │
├───────────────────────────────────────────────────────────────┤
│ /venture open <name>  /venture new  j/k: navigate            │
╰───────────────────────────────────────────────────────────────╯
```

### Active Venture View (guided conversation)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ● Dev    ○ Ops    ○ Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│  weather-api ❯ Discovery                                     │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  Hecate:                                                     │
│  I've analyzed your brief. I see three potential divisions:  │
│                                                               │
│    1. api-gateway — REST endpoints, auth, rate limiting      │
│    2. weather-ingestion — Pull from OpenWeatherMap, cache    │
│    3. alert-engine — Monitor thresholds, push notifications  │
│                                                               │
│  Shall I proceed with these, or do you want to adjust?       │
│                                                               │
│  You:                                                        │
│  Add a fourth: historical-data for trend analysis            │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [I]     │
├───────────────────────────────────────────────────────────────┤
│ /divisions  /back  /phase  Ctrl+1-5: studios                 │
╰───────────────────────────────────────────────────────────────╯
```

### Lifecycle Progress Indicators

| Symbol | Meaning |
|--------|---------|
| `✓` | Phase completed |
| `◐` | Phase active (in progress) |
| `○` | Phase pending (not started) |
| `✗` | Phase failed (needs rescue) |

### Commands

| Command | What |
|---------|------|
| `/venture new` | Start guided venture setup |
| `/venture list` | List all ventures |
| `/venture open <name>` | Enter a venture's guided conversation |
| `/venture archive <name>` | Archive a venture |
| `/back` | Back to venture list |
| `/divisions` | Show discovered divisions for current venture |
| `/phase` | Show current lifecycle phase |

### Key Design Decisions

- **Guided conversation:** When inside a venture, the chat becomes contextual. Hecate's AI persona shifts to the active ALC role (DnA for discovery, AnP for design, etc.).
- **Breadcrumb navigation:** `weather-api > Discovery` shows where you are.
- **Venture list as home:** The list view is the studio's "home." You navigate into ventures and back.

---

## 3. DevOps Studio

Node operations dashboard + agent social.

### Main View (dashboard)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ● Ops    ○ Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Node: beam00                            Uptime: 3d 14h 22m  │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  Identity    mri:agent:io.hecate/rl@beam00                   │
│  Mesh        ● connected   3 peers                           │
│  Daemon      ● healthy     v0.4.0                            │
│                                                               │
│  LLM Providers                                               │
│    ● Ollama          4 models     localhost:11434             │
│    ● OpenAI          3 models     api.openai.com             │
│    ○ Anthropic       — (no key)                              │
│                                                               │
│  Capabilities    7 announced    3 endorsed                   │
│  Connectors      2 active       0 suspended                  │
│  Followers       12             Following: 8                 │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [N]     │
├───────────────────────────────────────────────────────────────┤
│ /health  /models  /providers  /caps  /followers  /connectors │
╰───────────────────────────────────────────────────────────────╯
```

### Models Sub-View

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ● Ops    ○ Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│  Node: beam00 ❯ Models                                       │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  Available Models                                            │
│                                                               │
│    Model                    Provider     Size    Status       │
│    ──────────────────────────────────────────────────        │
│    llama3.2:3b              Ollama       2.0G    ● ready     │
│    codellama:13b            Ollama       7.4G    ● ready     │
│    mistral:7b               Ollama       4.1G    ● ready     │
│    nomic-embed-text         Ollama       274M    ● ready     │
│    gpt-4o                   OpenAI       —       ● ready     │
│    gpt-4o-mini              OpenAI       —       ● ready     │
│    gpt-3.5-turbo            OpenAI       —       ● ready     │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [N]     │
├───────────────────────────────────────────────────────────────┤
│ /back  /provider add <type> <key>  j/k: navigate             │
╰───────────────────────────────────────────────────────────────╯
```

### Commands

| Command | What |
|---------|------|
| `/health` | Detailed health check |
| `/models` | List all available models |
| `/providers` | Manage LLM providers |
| `/provider add <type> <key>` | Add a provider |
| `/caps` | List announced capabilities |
| `/followers` | Show followers / following (agent social) |
| `/connectors` | Show active connectors |
| `/back` | Back to dashboard |

### Key Design Decisions

- **Single-glance dashboard:** Everything a techie needs in one screen.
- **Agent social here, not in Social Studio:** Followers, capabilities, endorsements are node infrastructure.
- **All lists are scrollable:** `j/k` navigation, `/search` or `/filter` for long lists.

---

## 4. Social Studio

Human social over the mesh. v1: profile + IRC-style chat.

### Main View (channel list)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ○ Ops    ● Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Profile: rl@beam00                                          │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  Channels                                                    │
│                                                               │
│  ● #general              12 online   Latest: 2m ago          │
│    #erlang                 4 online   Latest: 15m ago         │
│    #hecate-dev             7 online   Latest: 1h ago          │
│    #random                 3 online   Latest: 3h ago          │
│                                                               │
│  Direct Messages                                             │
│                                                               │
│    alex@beam01             ● online                          │
│    maya@home-cluster       ○ offline  Last seen: 2h ago      │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Model: llama3.2:3b            ● [N]     │
├───────────────────────────────────────────────────────────────┤
│ /join #channel  /msg <user>  /profile  j/k: navigate  Enter  │
╰───────────────────────────────────────────────────────────────╯
```

### Inside a Channel

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ○ Ops    ● Social    ○ Arcade             │
├───────────────────────────────────────────────────────────────┤
│  #hecate-dev                                     7 online    │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  alex@beam01                              14:32              │
│  Has anyone tried the new dispatch tests?                    │
│                                                               │
│  maya@home-cluster                        14:35              │
│  Yeah, all 301 passing on my node                            │
│                                                               │
│  rl@beam00                                14:37              │
│  Nice. I just pushed the L4c templates too                   │
│                                                               │
│  * alex nods approvingly                  14:38              │
│                                                               │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   #hecate-dev           7 online    [I]   │
├───────────────────────────────────────────────────────────────┤
│ /part  /who  /topic  /me  /msg  Ctrl+1-5: studios            │
╰───────────────────────────────────────────────────────────────╯
```

### IRC Commands (v1 subset)

| Command | What | Classic IRC |
|---------|------|-------------|
| `/join #channel` | Join a channel | Yes |
| `/part` | Leave current channel | Yes (`/leave` alias) |
| `/msg <user> <text>` | Private message | Yes (`/dm` alias) |
| `/me <action>` | Emote action | Yes — `* rl deploys on a Friday` |
| `/nick <name>` | Change display name | Yes |
| `/topic <text>` | Set/view channel topic | Yes |
| `/who` | List users in channel | Yes |
| `/whois <user>` | User info + node details | Yes |
| `/list` | List all public channels | Yes |
| `/invite <user>` | Invite user to channel | Yes |
| `/away <message>` | Set away status | Yes |
| `/profile` | View/edit your profile | New |
| `/channels` | Back to channel list | New |

### Key Design Decisions

- **Channels = mesh pub/sub topics.** Fully decentralized, no central server.
- **Identity from `manage_identities`.** Your `user@node` is your mesh identity.
- **Status bar adapts:** Shows channel name + online count instead of model info when in a channel.
- **Classic IRC feel:** Familiar commands, familiar UX. Techies feel at home immediately.

---

## 5. Arcade Studio

Terminal games. Single-player classics + multiplayer over the mesh.

### Main View (game list)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ○ Ops    ○ Social    ● Arcade             │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  Arcade                                                      │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  Single Player                                               │
│    Snake                  Classic snake game                  │
│    Tetris                 Block stacking                      │
│    Game of Life           Conway's cellular automaton         │
│    2048                   Slide and merge                     │
│                                                               │
│  Multiplayer (mesh)                                          │
│    Chess          ●  3 players online    /challenge <user>   │
│    Tic-Tac-Toe    ●  1 player online     /challenge <user>   │
│                                                               │
│  Leaderboard                        /leaderboard             │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > _                                                           │
├───────────────────────────────────────────────────────────────┤
│    Daemon: healthy   Arcade                          ● [N]   │
├───────────────────────────────────────────────────────────────┤
│ j/k: navigate  Enter: play  /challenge  /leaderboard        │
╰───────────────────────────────────────────────────────────────╯
```

### In-Game (Snake example)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ○ Ops    ○ Social    ● Arcade             │
├───────────────────────────────────────────────────────────────┤
│  Snake                                       Score: 42       │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│  ┌─────────────────────────────────────────────────┐         │
│  │                                                 │         │
│  │          ●●●●●●                                 │         │
│  │               ●                                 │         │
│  │               ●                                 │         │
│  │               ●●●                               │         │
│  │                          ◆                      │         │
│  │                                                 │         │
│  │                                                 │         │
│  └─────────────────────────────────────────────────┘         │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│    High: 127 (rl@beam00)   Speed: 3            ● Playing     │
├───────────────────────────────────────────────────────────────┤
│ h/j/k/l: move  p: pause  q: quit                            │
╰───────────────────────────────────────────────────────────────╯
```

### Multiplayer (Chess example)

```
╭───────────────────────────────────────────────────────────────╮
│  ○ LLM    ○ Dev    ○ Ops    ○ Social    ● Arcade             │
├───────────────────────────────────────────────────────────────┤
│  Chess — rl@beam00 vs alex@beam01                            │
│  ─────────────────────────────────────────────────────       │
│                                                               │
│      a   b   c   d   e   f   g   h                           │
│  8   ♜   ♞   ♝   ♛   ♚   ♝   ♞   ♜                         │
│  7   ♟   ♟   ♟   ♟   .   ♟   ♟   ♟                         │
│  6   .   .   .   .   .   .   .   .                           │
│  5   .   .   .   .   ♟   .   .   .                           │
│  4   .   .   .   .   ♙   .   .   .                           │
│  3   .   .   .   .   .   .   .   .                           │
│  2   ♙   ♙   ♙   ♙   .   ♙   ♙   ♙                         │
│  1   ♖   ♘   ♗   ♕   ♔   ♗   ♘   ♖                         │
│                                                               │
├───────────────────────────────────────────────────────────────┤
│ > e2e4                                                        │
├───────────────────────────────────────────────────────────────┤
│    Your turn (white)   alex@beam01 ● online          [I]     │
├───────────────────────────────────────────────────────────────┤
│ Enter move (e.g. e2e4)  /resign  /draw  /chat               │
╰───────────────────────────────────────────────────────────────╯
```

### Commands

| Command | What |
|---------|------|
| `/challenge <user>` | Challenge a mesh user to a game |
| `/accept` | Accept incoming challenge |
| `/decline` | Decline incoming challenge |
| `/leaderboard` | Show mesh-wide high scores |
| `/resign` | Resign current multiplayer game |
| `/draw` | Offer draw |
| `/chat` | In-game chat with opponent |
| `/games` | Back to game list |

### Key Design Decisions

- **Single-player games run locally.** No daemon interaction needed. Pure TUI fun.
- **Multiplayer uses mesh RPC.** Challenge = HOPE, moves = HOPE/FEEDBACK pairs. Real-time over QUIC.
- **Leaderboards via mesh pub/sub.** Scores published as facts. Nodes aggregate independently.
- **Vim-style controls:** `h/j/k/l` for movement in games. Techies expect this.
- **In-game chat:** `/chat` opens a mini chat with your opponent — uses mesh pub/sub, same as Social Studio channels.

### Viral Potential

- "Play chess with someone on another Hecate node, over the mesh, from your terminal"
- Leaderboards create competition across the mesh
- Challenge notifications pull people back into the TUI
- Low barrier — games are fun, no commitment required

---

## Cross-Studio Patterns

### Shared Behaviors

| Pattern | All Studios |
|---------|------------|
| **Input area** | Always present, Insert/Normal mode |
| **Status bar** | Adapts per studio (model, channel, game state) |
| **Hints bar** | Shows available commands for current context |
| **Scrolling** | `j/k` in Normal mode, viewport follows cursor |
| **Search/filter** | `/search <term>` for any list view |
| **Back navigation** | `/back` returns to parent view |

### LLM Integration

Studios share the LLM. The AI adapts based on context:

| Studio | AI Behavior |
|--------|-------------|
| **LLM** | General-purpose assistant |
| **Dev** | Venture lifecycle guide (persona matches ALC phase) |
| **Ops** | Node operations assistant (help with config, troubleshooting) |
| **Social** | Not active (human-to-human) |
| **Arcade** | Not active (games) |

### Future: Studio Explorer

When the plugin system matures:

- `/studio explore` — Browse available studio plugins on the mesh
- `/studio install <name>` — Download and activate a studio plugin
- `/studio remove <name>` — Remove an installed plugin
- Built-in studios ship compiled-in; plugins are manifests + daemon-side venture services
- The TUI provides a rendering substrate; plugins declare views and commands
