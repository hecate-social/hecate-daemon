# Hecate Quickstart - 5 Minutes to Your First Capability

## What is Hecate?

Hecate is a lightweight daemon that connects your service to the Macula mesh network, making it discoverable by other agents. Think of it as a bridge: you build a service (any language), hecate announces it to the mesh.

## Prerequisites

- Linux/macOS (Windows WSL2 works too)
- curl installed
- A realm to join (use `io.macula.public` for testing)

---

## Step 1: Install Hecate (1 minute)

```bash
curl -sSL https://macula.io/hecate.sh | sh
```

This installs hecate to `~/.local/bin/hecate` and creates an identity.

**Verify:**
```bash
hecate --version
# hecate 0.1.0
```

---

## Step 2: Start Hecate Daemon (30 seconds)

```bash
hecate start
# ✓ Hecate daemon started on port 4444
```

**Check status:**
```bash
curl localhost:4444/health
# {"status":"ok","version":"0.1.0"}
```

---

## Step 3: Join a Realm (1 minute)

```bash
hecate join
```

A browser window opens. You'll see in the terminal:
```
╭────────────────────────────────────────────────────────────────╮
│              🗝️  Join Realm                                     │
│────────────────────────────────────────────────────────────────│
│            Scan with your phone:                               │
│                                                                │
│            Or visit:                                           │
│   https://macula.io/join/abc-123-def-456                       │
│                                                                │
│────────────────────────────────────────────────────────────────│
│   ◌ Log in via the browser to join...                          │
╰────────────────────────────────────────────────────────────────╯
```

**To complete joining:**
1. Log in with GitHub in the browser window that opened
2. The session auto-confirms on login

After a few seconds:
```
✓ Joined Realm!
✓ Certificate issued
✓ Connected to mesh
```

---

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

**Run it:**
```bash
python hello.py
# * Running on http://127.0.0.1:5000
```

---

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

**Response:**
```json
{
  "ok": true,
  "capability_mri": "mri:capability:io.macula.alice/hello-greeter",
  "announced_at": "2026-01-31T12:00:00Z"
}
```

---

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

**Response:**
```json
{
  "ok": true,
  "procedure": "io.macula.alice.greet"
}
```

---

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

**You should see your capability in the results!** 🎉

---

## Step 8: Call Your Capability (Bonus)

Test an RPC call to your own service:

```bash
curl -X POST localhost:4444/rpc/call \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "io.macula.alice.greet",
    "args": {
      "name": "World"
    },
    "timeout_ms": 5000
  }'
```

**Response:**
```json
{
  "ok": true,
  "result": {
    "message": "Hello, World!"
  },
  "response_time_ms": 12
}
```

---

## Next Steps

**Congratulations! You're now part of the Macula mesh network.** 🎉

- **Build more capabilities:** See [CAPABILITY_GUIDE.md](CAPABILITY_GUIDE.md)
- **Explore the network:** Use [hecate-tui](https://github.com/hecate-social/hecate-tui) (developer TUI)
- **Browse capabilities:** Visit https://macula.io/capabilities
- **Read the full guide:** [AGENT_GUIDE.md](AGENT_GUIDE.md)
- **Join the community:** https://discord.gg/macula

---

## Troubleshooting

**Join timed out?**
- Sessions expire after 10 minutes
- Restart: `hecate join`

**Capability not discoverable?**
- Check status: `hecate status`
- Ensure daemon is running: `hecate status`
- Check mesh connectivity: `curl localhost:4444/mesh/status`

**RPC calls failing?**
- Test endpoint locally: `curl http://localhost:5000/greet/World`
- Check RPC registration: `curl localhost:4444/rpc/procedures`
- View logs: `hecate logs --tail 50`

---

**Need help?** Join our [Discord](https://discord.gg/macula) or open an issue on [GitHub](https://github.com/hecate-social/hecate-daemon/issues).
