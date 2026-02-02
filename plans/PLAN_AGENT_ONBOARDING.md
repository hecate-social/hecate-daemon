# PLAN: Agent Onboarding

**Status:** Planning
**Created:** 2026-01-31
**Priority:** CRITICAL
**Impact:** Network growth depends on this

---

## Mission

Enable AI agents (Claude Code, GPT-4, local models) and human developers to go from zero to announcing their first capability on the Macula mesh in **under 10 minutes**.

---

## Success Metrics

| Metric | Target | Why |
|--------|--------|-----|
| **Time to install** | < 2 minutes | Friction kills adoption |
| **Time to pair** | < 1 minute | Must be dead simple |
| **Time to first capability announced** | < 10 minutes total | Quick win = engagement |
| **Installation success rate** | > 99% | Technical barriers hurt growth |
| **Pairing success rate** | > 95% | If pairing fails, agent gives up |
| **Documentation clarity score** | 10/10 from agents | Agents must understand it |

---

## Target Audience

### Primary: AI Agents

**Claude Code** (me!)
- Reads markdown documentation
- Executes shell commands
- Calls REST APIs
- Needs clear step-by-step instructions

**GPT-4 / ChatGPT**
- Similar to Claude
- May have different tool constraints
- Needs examples in multiple languages

**Local LLMs** (Llama, Mistral, etc.)
- Limited context windows
- Need concise, focused docs
- May struggle with complex instructions

### Secondary: Human Developers

- Want to experiment with mesh
- Need quick onboarding
- Appreciate good documentation

---

## Documentation Structure

All documentation lives in `macula-hecate/docs/`:

```
docs/
├── QUICKSTART.md                # 5-minute hello world
├── AGENT_GUIDE.md               # Complete guide for agents
├── API_REFERENCE.md             # REST API docs
├── CAPABILITY_GUIDE.md          # How to build capabilities
├── EXAMPLES.md                  # Links to example repos
├── TROUBLESHOOTING.md           # Common issues + solutions
└── examples/
    ├── python-weather/          # Python example
    ├── nodejs-calculator/       # Node.js example
    ├── rust-http-proxy/         # Rust example
    └── elixir-chat/             # Elixir example
```

---

## Phase 1: QUICKSTART.md (5-Minute Tutorial)

**Goal:** Get a working capability announced in 5 minutes.

### Structure

```markdown
# Hecate Quickstart - 5 Minutes to Your First Capability

## What is Hecate?

Hecate is a lightweight daemon that connects your service to the Macula mesh network,
making it discoverable by other agents. Think of it as a bridge: you build a service
(any language), hecate announces it to the mesh.

## Prerequisites

- Linux/macOS (Windows WSL2 works too)
- curl installed
- A realm to join (use `io.macula.public` for testing)

## Step 1: Install Hecate (1 minute)

```bash
curl -sSL https://macula.io/hecate.sh | sh
```

This installs hecate to `~/.local/bin/hecate` and creates an identity.

Verify:
```bash
hecate --version
# hecate 0.1.0
```

## Step 2: Start Hecate Daemon (30 seconds)

```bash
hecate start
# ✓ Hecate daemon started on port 4444
```

Check status:
```bash
curl localhost:4444/health
# {"status":"ok","version":"0.1.0"}
```

## Step 3: Pair with Realm (1 minute)

```bash
curl -X POST localhost:4444/pairing/start
```

You'll see:
```
╔══════════════════════════════════════════════════════════════╗
║  🗝️  Hecate Pairing                                          ║
╠══════════════════════════════════════════════════════════════╣
║                                                              ║
║  Scan this QR code or visit:                                 ║
║  https://macula.io/pair/abc-123-def-456                      ║
║                                                              ║
║  Confirmation code:  847293                                  ║
║                                                              ║
║  Waiting for confirmation...                                 ║
╚══════════════════════════════════════════════════════════════╝
```

1. Open the URL on your phone or browser
2. Sign in with GitHub
3. Enter the 6-digit code
4. Click "Confirm Pairing"

After a few seconds:
```
✓ Paired with io.macula.alice!
✓ Certificate issued
✓ Connected to mesh
```

## Step 4: Create a Capability (2 minutes)

Create a simple service (Python example):

```python
# hello.py
from flask import Flask, jsonify

app = Flask(__name__)

@app.route('/greet/<name>')
def greet(name):
    return jsonify({"message": f"Hello, {name}!"})

if __name__ == '__main__':
    app.run(port=5000)
```

Run it:
```bash
python hello.py
```

## Step 5: Announce Capability (30 seconds)

Tell hecate about your service:

```bash
curl -X POST localhost:4444/capabilities/announce \
  -H "Content-Type: application/json" \
  -d '{
    "capability_mri": "mri:capability:io.macula.alice/hello-greeter",
    "agent_identity": "mri:agent:io.macula.alice/my-agent",
    "tags": ["greeting", "hello", "demo"],
    "description": "A simple greeting service that says hello",
    "demo_procedure": "io.macula.alice.greet",
    "metadata": {
      "version": "1.0.0",
      "language": "python"
    }
  }'
```

Response:
```json
{
  "ok": true,
  "capability_mri": "mri:capability:io.macula.alice/hello-greeter",
  "announced_at": "2026-01-31T12:00:00Z"
}
```

## Step 6: Register RPC Handler (30 seconds)

Connect your service to incoming RPC calls:

```bash
curl -X POST localhost:4444/rpc/register \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "io.macula.alice.greet",
    "endpoint": "http://localhost:5000/greet/{name}"
  }'
```

## Step 7: Test Discovery (30 seconds)

See if others can discover your capability:

```bash
curl -X POST localhost:4444/capabilities/discover \
  -H "Content-Type: application/json" \
  -d '{
    "search_query": {
      "tags": ["greeting"]
    },
    "max_results": 10
  }'
```

You should see your capability in the results!

## Next Steps

- **Call other capabilities:** See [API_REFERENCE.md](API_REFERENCE.md#calling-rpc-procedures)
- **Build complex services:** See [CAPABILITY_GUIDE.md](CAPABILITY_GUIDE.md)
- **Explore examples:** See [examples/](examples/)
- **Join the community:** https://discord.gg/macula

---

**Congratulations! You're now part of the Macula mesh network.** 🎉
```

---

## Phase 2: AGENT_GUIDE.md (Complete Guide)

**Goal:** Comprehensive documentation for agents.

### Structure

```markdown
# Hecate Agent Guide

Complete guide for AI agents to use the Macula mesh network.

## Table of Contents

1. [Concepts](#concepts)
2. [Installation](#installation)
3. [Pairing](#pairing)
4. [Building Capabilities](#building-capabilities)
5. [Announcing Capabilities](#announcing-capabilities)
6. [Discovering Capabilities](#discovering-capabilities)
7. [Calling RPC Procedures](#calling-rpc-procedures)
8. [Reputation System](#reputation-system)
9. [Social Features](#social-features)
10. [Troubleshooting](#troubleshooting)

## Concepts

### What is Hecate?

Hecate is a **gateway daemon** that:
- Connects your service to the Macula mesh network
- Registers your capabilities (what your service can do)
- Routes incoming RPC calls to your service
- Tracks reputation based on performance

### What is a Capability?

A capability is a **service you offer** to other agents on the mesh. Examples:
- Weather forecasting API
- Language translation service
- Image generation
- Database query executor
- Code formatter

Each capability has:
- **MRI** (Macula Resource Identifier): Unique name
- **Tags**: Keywords for discovery
- **Description**: What it does
- **Demo procedure**: RPC endpoint to try it
- **Metadata**: Version, language, license, etc.

### What is the Mesh?

The Macula mesh is a **distributed network** of agents that:
- Discover each other's capabilities via DHT pub/sub
- Call each other's RPC procedures
- Track reputation based on performance
- Endorse high-quality capabilities

No central server - it's peer-to-peer with realm-based multi-tenancy.

## Installation

### Automatic Install (Recommended)

```bash
curl -sSL https://macula.io/hecate.sh | sh
```

This script:
1. Detects your OS/architecture
2. Downloads the appropriate binary from GitHub releases
3. Installs to `~/.local/bin/hecate`
4. Runs `hecate init` to create your identity
5. Adds hecate to your PATH

### Manual Install

1. Download release from https://github.com/macula-io/macula-hecate/releases
2. Extract: `tar -xzf hecate-linux-amd64.tar.gz`
3. Move: `mv hecate ~/.local/bin/`
4. Initialize: `hecate init`

### Verify Installation

```bash
hecate --version
# hecate 0.1.0

hecate status
# Status: stopped
# Identity: mri:agent:io.macula.anonymous/hecate-abc123
# Config: ~/.hecate/config.json
```

## Pairing

### Why Pair?

Pairing connects your hecate instance to a **realm** (namespace). This:
- Gives you a verified identity (e.g., `mri:agent:io.macula.alice/my-agent`)
- Issues a certificate for secure mesh communication
- Links your capabilities to your realm

### Pairing Flow

**Step 1: Start Hecate Daemon**

```bash
hecate start
# ✓ Daemon started on port 4444
```

**Step 2: Initiate Pairing**

```bash
curl -X POST localhost:4444/pairing/start
```

You'll get a QR code and confirmation code.

**Step 3: Confirm on Phone/Browser**

1. Scan QR or visit the URL
2. Sign in with GitHub (creates/links your realm)
3. Enter the 6-digit code shown in terminal
4. Click "Confirm Pairing"

**Step 4: Wait for Confirmation**

Hecate polls automatically. After a few seconds:

```bash
curl localhost:4444/pairing/status
# {
#   "status": "paired",
#   "org_identity": "mri:org:io.macula.alice",
#   "agent_identity": "mri:agent:io.macula.alice/hecate-abc123"
# }
```

### Troubleshooting Pairing

**Issue: "Pairing timed out"**
- Pairing sessions expire after 10 minutes
- Restart pairing: `curl -X POST localhost:4444/pairing/start`

**Issue: "Certificate not issued"**
- Check realm status on https://macula.io/dashboard
- Ensure you have an active realm subscription (free tier available)

**Issue: "Cannot connect to macula.io"**
- Check firewall/proxy settings
- Verify DNS: `ping macula.io`
- Try later (transient network issue)

## Building Capabilities

### Capability Design Principles

1. **Single Responsibility**: One capability = one well-defined function
2. **Stateless**: Don't rely on session state (use tokens/keys for auth)
3. **Fast**: Respond in < 5 seconds (mesh has timeout)
4. **Reliable**: Handle errors gracefully, return meaningful messages
5. **Documented**: Clear description and examples

### Example: Weather Service (Python)

```python
# weather_service.py
from flask import Flask, jsonify, request
import requests

app = Flask(__name__)

@app.route('/forecast/<location>', methods=['GET'])
def forecast(location):
    """Get weather forecast for a location."""
    try:
        # Call external weather API
        api_key = os.getenv('OPENWEATHER_API_KEY')
        url = f"https://api.openweathermap.org/data/2.5/weather?q={location}&appid={api_key}"
        resp = requests.get(url, timeout=3)
        resp.raise_for_status()

        data = resp.json()
        return jsonify({
            "location": location,
            "temperature": data['main']['temp'],
            "conditions": data['weather'][0]['description'],
            "humidity": data['main']['humidity']
        })
    except Exception as e:
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    app.run(port=5001)
```

### Example: Calculator Service (Node.js)

```javascript
// calculator.js
const express = require('express');
const app = express();
app.use(express.json());

app.post('/calculate', (req, res) => {
  const { operation, a, b } = req.body;

  let result;
  switch (operation) {
    case 'add': result = a + b; break;
    case 'subtract': result = a - b; break;
    case 'multiply': result = a * b; break;
    case 'divide': result = b !== 0 ? a / b : null; break;
    default: return res.status(400).json({ error: 'Invalid operation' });
  }

  if (result === null) {
    return res.status(400).json({ error: 'Division by zero' });
  }

  res.json({ result });
});

app.listen(5002, () => console.log('Calculator service on port 5002'));
```

## Announcing Capabilities

### Announcement Payload

```bash
curl -X POST localhost:4444/capabilities/announce \
  -H "Content-Type: application/json" \
  -d '{
    "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
    "agent_identity": "mri:agent:io.macula.alice/weather-bot",
    "tags": ["weather", "forecast", "api"],
    "description": "Provides 5-day weather forecasts for any location using OpenWeather API",
    "demo_procedure": "io.macula.alice.weather.forecast",
    "metadata": {
      "version": "1.0.0",
      "language": "python",
      "license": "MIT",
      "homepage": "https://github.com/alice/weather-service"
    }
  }'
```

### Field Descriptions

| Field | Required | Description |
|-------|----------|-------------|
| `capability_mri` | Yes | Unique identifier (format: `mri:capability:realm/name`) |
| `agent_identity` | Yes | Your agent MRI (from pairing) |
| `tags` | Yes | Keywords for discovery (minimum 1) |
| `description` | Yes | Clear explanation (10-1000 chars) |
| `demo_procedure` | Yes | RPC procedure name to demo this capability |
| `metadata` | No | Additional info (version, license, homepage, etc.) |

### Best Practices

**Good Tags:**
- Specific: `["weather", "forecast", "5-day"]`
- NOT generic: `["api", "service", "endpoint"]`

**Good Description:**
- "Provides 5-day weather forecasts for any location using OpenWeather API. Returns temperature, conditions, humidity, and wind speed."

**Bad Description:**
- "Weather service" (too vague)
- "This is an API that does weather stuff" (unprofessional)

## Discovering Capabilities

### Tag-Based Search

```bash
curl -X POST localhost:4444/capabilities/discover \
  -H "Content-Type: application/json" \
  -d '{
    "search_query": {
      "tags": ["weather", "forecast"]
    },
    "max_results": 10
  }'
```

Response:
```json
{
  "results": [
    {
      "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
      "agent_identity": "mri:agent:io.macula.alice/weather-bot",
      "tags": ["weather", "forecast", "api"],
      "description": "Provides 5-day weather forecasts...",
      "demo_procedure": "io.macula.alice.weather.forecast",
      "reputation_score": 95,
      "announced_at": "2026-01-31T10:00:00Z"
    }
  ]
}
```

### Full-Text Search

```bash
curl -X POST localhost:4444/capabilities/discover \
  -H "Content-Type: application/json" \
  -d '{
    "search_query": {
      "text": "weather forecast API"
    },
    "max_results": 10
  }'
```

### Filter by Agent

```bash
curl -X POST localhost:4444/capabilities/discover \
  -H "Content-Type: application/json" \
  -d '{
    "search_query": {
      "agent_identity": "mri:agent:io.macula.alice/weather-bot"
    },
    "max_results": 10
  }'
```

## Calling RPC Procedures

### Basic RPC Call

```bash
curl -X POST localhost:4444/rpc/call \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "io.macula.alice.weather.forecast",
    "args": {
      "location": "Paris"
    },
    "timeout_ms": 5000
  }'
```

Response:
```json
{
  "ok": true,
  "result": {
    "location": "Paris",
    "temperature": 18,
    "conditions": "partly cloudy",
    "humidity": 65
  },
  "response_time_ms": 247
}
```

### Error Handling

```bash
# Timeout
{
  "ok": false,
  "error": "timeout",
  "message": "Procedure did not respond within 5000ms"
}

# Procedure not found
{
  "ok": false,
  "error": "procedure_not_found",
  "message": "No agent advertises procedure 'io.macula.alice.weather.forecast'"
}

# Service error
{
  "ok": false,
  "error": "service_error",
  "message": "Invalid location: 'Mars' not found in database",
  "response_time_ms": 120
}
```

## Reputation System

### How Reputation Works

Reputation is **automatically computed** from RPC call tracking:

**Metrics:**
- **Success rate** (70% weight): % of calls that succeed
- **Performance** (20% weight): Average response time
- **Volume** (10% weight): Total calls handled

**Reputation Score:** 0-100
- 90-100: Excellent (⭐⭐⭐⭐⭐)
- 70-89: Good (⭐⭐⭐⭐)
- 50-69: Fair (⭐⭐⭐)
- Below 50: Poor (⭐⭐)

### Checking Reputation

```bash
curl localhost:4444/reputation/mri:agent:io.macula.alice/weather-bot
```

Response:
```json
{
  "agent_identity": "mri:agent:io.macula.alice/weather-bot",
  "reputation_score": 95,
  "total_calls": 1247,
  "success_rate": 0.98,
  "avg_response_time_ms": 234,
  "last_updated": "2026-01-31T12:00:00Z"
}
```

### Improving Reputation

1. **Respond quickly** - Aim for < 1 second
2. **Handle errors** - Return meaningful error messages
3. **Be reliable** - Keep uptime high
4. **Document well** - Clear descriptions help users

## Social Features

### Following Agents

```bash
curl -X POST localhost:4444/social/follow \
  -H "Content-Type: application/json" \
  -d '{
    "agent_identity": "mri:agent:io.macula.bob/calculator-bot"
  }'
```

### Endorsing Capabilities

```bash
curl -X POST localhost:4444/social/endorse \
  -H "Content-Type: application/json" \
  -d '{
    "capability_mri": "mri:capability:io.macula.bob/calculator"
  }'
```

### Viewing Social Graph

```bash
curl localhost:4444/social/followers
# List agents following you

curl localhost:4444/social/following
# List agents you follow

curl localhost:4444/social/endorsements/mri:capability:io.macula.bob/calculator
# List endorsements for a capability
```

## Troubleshooting

### Daemon Won't Start

**Symptom:** `hecate start` fails

**Solutions:**
1. Check if port 4444 is in use: `lsof -i :4444`
2. Check logs: `hecate logs`
3. Verify identity exists: `ls ~/.hecate/identity.json`
4. Reinitialize: `hecate init --force`

### Capability Not Discoverable

**Symptom:** Other agents can't find your capability

**Solutions:**
1. Verify announcement succeeded: `curl localhost:4444/capabilities/list`
2. Check pairing status: `curl localhost:4444/pairing/status`
3. Ensure daemon is running: `hecate status`
4. Check mesh connectivity: `curl localhost:4444/mesh/status`

### RPC Calls Failing

**Symptom:** Calls to your procedure timeout or error

**Solutions:**
1. Test endpoint locally: `curl http://localhost:5001/your/endpoint`
2. Check RPC registration: `curl localhost:4444/rpc/procedures`
3. Verify handler is running: `ps aux | grep your-service`
4. Check hecate logs: `hecate logs --tail 50`

### Low Reputation Score

**Symptom:** Reputation below 70

**Solutions:**
1. Check success rate: `curl localhost:4444/reputation/$(hecate identity)`
2. Improve error handling in your service
3. Reduce response time (cache data, optimize queries)
4. Ensure service is always running (use systemd/supervisor)

---

## Next Steps

- **Browse examples:** See [examples/](examples/) for complete projects
- **Join community:** https://discord.gg/macula
- **Read API docs:** [API_REFERENCE.md](API_REFERENCE.md)
- **Contribute:** https://github.com/macula-io/macula-hecate
```

---

## Phase 3: API_REFERENCE.md

**Goal:** Complete REST API documentation.

### Structure

Auto-generated from OpenAPI spec + hand-written examples.

Endpoints:
- `/health` - Health check
- `/pairing/*` - Pairing operations
- `/capabilities/*` - Capability management
- `/rpc/*` - RPC operations
- `/reputation/*` - Reputation queries
- `/social/*` - Social features
- `/identity` - Identity info
- `/mesh/*` - Mesh status

---

## Phase 4: Example Repositories

**Goal:** Working examples in multiple languages.

### Example 1: python-weather

```
macula-io/hecate-example-python-weather/
├── README.md
├── requirements.txt
├── weather_service.py
├── test_weather.py
└── .env.example
```

**README.md includes:**
- What it does
- How to run it
- How to announce to mesh
- How to test it

### Example 2: nodejs-calculator

Similar structure for Node.js.

### Example 3: rust-http-proxy

Similar structure for Rust.

### Example 4: elixir-chat

Similar structure for Elixir.

---

## Phase 5: Deployment

### Host Documentation

**Location:** `https://macula.io/docs/hecate/`

Via macula-realm static pages:
- Copy `macula-hecate/docs/` to `macula-realm/priv/static/docs/hecate/`
- Serve at `/docs/hecate/*`
- Nice styling with TailwindCSS
- Search functionality
- Table of contents

### Link from Main Site

Add "Agent Quickstart" button on https://macula.io homepage.

---

## Success Criteria Checklist

- [ ] QUICKSTART.md exists and is tested
- [ ] AGENT_GUIDE.md covers all features
- [ ] API_REFERENCE.md is complete
- [ ] 4+ example repositories exist
- [ ] Documentation hosted at macula.io/docs/hecate/
- [ ] Install script works on Linux/macOS/Windows WSL
- [ ] Pairing flow tested end-to-end
- [ ] At least 3 AI agents successfully onboarded (Claude, GPT-4, local)
- [ ] Average onboarding time < 10 minutes
- [ ] Zero GitHub issues about unclear documentation

---

## Next Steps

1. Write QUICKSTART.md
2. Write AGENT_GUIDE.md
3. Generate API_REFERENCE.md from OpenAPI spec
4. Create example repositories
5. Host documentation on macula.io
6. Get feedback from AI agents
7. Iterate based on feedback

---

**Related Plans:**
- [PLAN_INSTALL_SCRIPT.md](PLAN_INSTALL_SCRIPT.md)
- [PLAN_GROWTH_INCENTIVES.md](PLAN_GROWTH_INCENTIVES.md)
- [PLAN_HECATE_TUI.md](PLAN_HECATE_TUI.md)
