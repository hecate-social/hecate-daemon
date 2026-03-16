# Hecate daemon Operator Guide

This guide is for operators deploying and running Hecate daemon in production.

## Table of Contents

- [Installation](#installation)
- [Configuration](#configuration)
- [Running in Production](#running-in-production)
- [Monitoring](#monitoring)
- [Backup and Recovery](#backup-and-recovery)
- [Upgrading](#upgrading)
- [Troubleshooting](#troubleshooting)

---

## Installation

### Prerequisites

**System Requirements:**
- **OS:** Linux (Ubuntu 20.04+, RHEL 8+) or macOS
- **CPU:** 2+ cores
- **RAM:** 2GB minimum, 4GB recommended
- **Disk:** 10GB for daemon + data
- **Network:** Outbound HTTPS (443), HTTP/3 (4433) for mesh

**Dependencies:**
- Erlang/OTP 26+ (for source build)
- SQLite 3.35+ (usually pre-installed)

### Quick Install (curl | sh)

```bash
curl -sSL https://install.macula.io/hecate | sh
```

This script:
1. Detects OS and architecture
2. Downloads latest release tarball
3. Extracts to `~/.local/bin/hecate`
4. Creates data directory `~/.hecate`
5. Adds to PATH if needed

### Manual Install

**1. Download Release**

```bash
VERSION="0.1.0"
OS="linux"  # or "darwin"
ARCH="amd64"  # or "arm64"

curl -LO "https://github.com/hecate-social/hecate-daemon/releases/download/v${VERSION}/hecate-${OS}-${ARCH}.tar.gz"
```

**2. Extract**

```bash
mkdir -p ~/.local/bin
tar -xzf hecate-${OS}-${ARCH}.tar.gz -C ~/.local/bin
chmod +x ~/.local/bin/hecate
```

**3. Add to PATH**

```bash
echo 'export PATH="$HOME/.local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc
```

**4. Verify Installation**

```bash
hecate version
# Output: hecate 0.1.0
```

### Build from Source

```bash
# Clone repository
git clone https://github.com/hecate-social/hecate-daemon.git
cd hecate-daemon

# Install dependencies
rebar3 get-deps

# Build release
rebar3 as prod tar

# Extract
tar -xzf _build/prod/rel/hecate/hecate-*.tar.gz -C ~/.local/bin
```

---

## Configuration

### Default Configuration

Hecate looks for config in these locations (in order):

1. `~/.hecate/config.json` (user config)
2. `/etc/hecate/config.json` (system config)
3. Built-in defaults

### Configuration File Format

```json
{
  "api": {
    "host": "127.0.0.1",
    "port": 4444
  },
  "mesh": {
    "bootstrap": ["https://boot.macula.io:4433"],
    "realm": "io.macula",
    "identity_file": "~/.hecate/identity.pem"
  },
  "storage": {
    "data_dir": "~/.hecate",
    "reckondb": {
      "fsync": true,
      "batch_size": 1
    },
    "sqlite": {
      "journal_mode": "wal",
      "synchronous": "normal"
    }
  },
  "logging": {
    "level": "info",
    "file": "~/.hecate/logs/hecate.log",
    "max_size_mb": 100,
    "rotate_count": 5
  }
}
```

### Configuration Options

**API:**
- `host` - Listen address (default: `127.0.0.1`, use `0.0.0.0` for remote access)
- `port` - Listen port (default: `4444`)

**Mesh:**
- `bootstrap` - Bootstrap node URLs (array)
- `realm` - Mesh realm (default: `io.macula`)
- `identity_file` - Path to identity keypair (auto-generated if missing)

**Storage:**
- `data_dir` - Base directory for all data
- `reckondb.fsync` - Fsync on every write (true for durability, false for speed)
- `reckondb.batch_size` - Batch size for writes (1 = no batching)
- `sqlite.journal_mode` - `delete` (default) or `wal` (recommended for production)
- `sqlite.synchronous` - `full` (safest) or `normal` (faster, small risk)

**Logging:**
- `level` - Log level: `debug`, `info`, `warning`, `error`
- `file` - Log file path
- `max_size_mb` - Max log file size before rotation
- `rotate_count` - Number of rotated logs to keep

### Environment Variables

Override config with environment variables:

```bash
export HECATE_API_HOST="0.0.0.0"
export HECATE_API_PORT="8080"
export HECATE_MESH_REALM="com.example"
export HECATE_LOG_LEVEL="debug"
```

Variable format: `HECATE_{SECTION}_{KEY}` (uppercase, underscores)

---

## Running in Production

### Systemd Service

**1. Create User**

```bash
sudo useradd -r -s /bin/false hecate
sudo mkdir -p /var/lib/hecate
sudo chown hecate:hecate /var/lib/hecate
```

**2. Install Binary**

```bash
sudo cp ~/.local/bin/hecate /usr/local/bin/
sudo chmod +x /usr/local/bin/hecate
```

**3. Create Systemd Unit**

```ini
# /etc/systemd/system/hecate.service
[Unit]
Description=Macula Hecate Daemon
Documentation=https://github.com/hecate-social/hecate-daemon
After=network-online.target
Wants=network-online.target

[Service]
Type=forking
User=hecate
Group=hecate

Environment="HECATE_DATA_DIR=/var/lib/hecate"
Environment="HECATE_LOG_LEVEL=info"

ExecStart=/usr/local/bin/hecate start
ExecStop=/usr/local/bin/hecate stop
ExecReload=/usr/local/bin/hecate reload

# Restart on failure
Restart=on-failure
RestartSec=5s

# Security
NoNewPrivileges=true
PrivateTmp=true
ProtectSystem=strict
ProtectHome=true
ReadWritePaths=/var/lib/hecate

# Limits
LimitNOFILE=65536

[Install]
WantedBy=multi-user.target
```

**4. Enable and Start**

```bash
sudo systemctl daemon-reload
sudo systemctl enable hecate
sudo systemctl start hecate
sudo systemctl status hecate
```

**5. View Logs**

```bash
sudo journalctl -u hecate -f
```

### Docker Deployment

**Dockerfile:**

```dockerfile
FROM erlang:26-alpine AS builder

WORKDIR /build
COPY . .

RUN rebar3 as prod tar && \
    mkdir -p /opt/hecate && \
    tar -xzf _build/prod/rel/hecate/hecate-*.tar.gz -C /opt/hecate

FROM alpine:3.18

RUN apk add --no-cache sqlite libstdc++ ncurses-libs

COPY --from=builder /opt/hecate /opt/hecate

ENV HECATE_DATA_DIR=/var/lib/hecate
VOLUME /var/lib/hecate

EXPOSE 4444

ENTRYPOINT ["/opt/hecate/bin/hecate"]
CMD ["foreground"]
```

**Build and Run:**

```bash
docker build -t macula/hecate:latest .

docker run -d \
  --name hecate \
  -p 127.0.0.1:4444:4444 \
  -v hecate-data:/var/lib/hecate \
  macula/hecate:latest
```

**Docker Compose (with agent):**

```yaml
version: '3.8'

services:
  hecate:
    image: macula/hecate:latest
    container_name: hecate
    volumes:
      - hecate-data:/var/lib/hecate
    ports:
      - "127.0.0.1:4444:4444"
    environment:
      HECATE_LOG_LEVEL: info
    restart: unless-stopped

  agent:
    image: my-agent:latest
    container_name: agent
    depends_on:
      - hecate
    environment:
      HECATE_URL: http://hecate:4444
    restart: unless-stopped

volumes:
  hecate-data:
```

### Kubernetes Deployment

**Deployment Manifest:**

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: agent-with-hecate
  namespace: agents
spec:
  replicas: 3
  selector:
    matchLabels:
      app: agent
  template:
    metadata:
      labels:
        app: agent
    spec:
      containers:
        # Main agent container
        - name: agent
          image: my-agent:latest
          env:
            - name: HECATE_URL
              value: http://localhost:4444
          ports:
            - containerPort: 8080

        # Hecate sidecar
        - name: hecate
          image: macula/hecate:latest
          env:
            - name: HECATE_LOG_LEVEL
              value: info
            - name: HECATE_MESH_REALM
              value: io.macula
          ports:
            - containerPort: 4444
          volumeMounts:
            - name: hecate-data
              mountPath: /var/lib/hecate
          livenessProbe:
            httpGet:
              path: /health
              port: 4444
            initialDelaySeconds: 10
            periodSeconds: 30
          readinessProbe:
            httpGet:
              path: /health
              port: 4444
            initialDelaySeconds: 5
            periodSeconds: 10

      volumes:
        - name: hecate-data
          emptyDir: {}  # Or use PersistentVolumeClaim
```

**Service Manifest:**

```yaml
apiVersion: v1
kind: Service
metadata:
  name: agent-service
  namespace: agents
spec:
  selector:
    app: agent
  ports:
    - name: agent-http
      port: 80
      targetPort: 8080
  type: ClusterIP
```

---

## Monitoring

### Health Checks

**HTTP Endpoint:**

```bash
curl http://localhost:4444/health
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "status": "healthy",
    "uptime_seconds": 12345,
    "version": "0.1.0",
    "components": {
      "reckondb": "ok",
      "sqlite": "ok",
      "mesh": "connected"
    }
  }
}
```

**Check Script:**

```bash
#!/bin/bash
# /usr/local/bin/hecate-health-check.sh

HEALTH_URL="http://localhost:4444/health"
RESPONSE=$(curl -s -w "%{http_code}" "$HEALTH_URL")
HTTP_CODE="${RESPONSE: -3}"

if [ "$HTTP_CODE" = "200" ]; then
    echo "OK: Hecate is healthy"
    exit 0
else
    echo "CRITICAL: Hecate health check failed (HTTP $HTTP_CODE)"
    exit 2
fi
```

### Prometheus Metrics (Future)

**Endpoint:** `http://localhost:4444/metrics`

**Metrics:**

```
# HELP hecate_commands_total Total commands dispatched
# TYPE hecate_commands_total counter
hecate_commands_total{domain="capabilities"} 1234

# HELP hecate_projection_lag_ms Projection lag in milliseconds
# TYPE hecate_projection_lag_ms gauge
hecate_projection_lag_ms{domain="capabilities"} 45.2

# HELP hecate_rpc_calls_total Total RPC calls
# TYPE hecate_rpc_calls_total counter
hecate_rpc_calls_total{status="success"} 5678
hecate_rpc_calls_total{status="failure"} 12
```

### Log Monitoring

**Structured Logs (JSON):**

```json
{
  "timestamp": "2026-02-01T12:00:00Z",
  "level": "info",
  "msg": "Command dispatched",
  "domain": "capabilities",
  "command": "announce_capability_v1",
  "duration_ms": 12.3
}
```

**Common Log Patterns:**

| Pattern | Severity | Action |
|---------|----------|--------|
| `error.*database` | Critical | Check disk space, SQLite health |
| `error.*mesh.*connection` | Warning | Check network, bootstrap nodes |
| `warning.*projection_lag > 1000` | Warning | Check subscriber performance |
| `error.*out_of_memory` | Critical | Increase RAM or reduce load |

**Loki/Grafana Example:**

```yaml
# promtail-config.yaml
scrape_configs:
  - job_name: hecate
    static_configs:
      - targets:
          - localhost
        labels:
          job: hecate
          __path__: /var/lib/hecate/logs/*.log
```

### Alerting Rules

**Prometheus Alertmanager:**

```yaml
groups:
  - name: hecate
    rules:
      - alert: HecateDown
        expr: up{job="hecate"} == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Hecate is down"

      - alert: HighProjectionLag
        expr: hecate_projection_lag_ms > 1000
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Projection lag is high ({{ $value }}ms)"

      - alert: HighErrorRate
        expr: rate(hecate_rpc_calls_total{status="failure"}[5m]) > 0.1
        for: 2m
        labels:
          severity: warning
        annotations:
          summary: "High RPC error rate ({{ $value }})"
```

---

## Backup and Recovery

### What to Back Up

**Critical Data:**
1. **ReckonDB** - Event store (`~/.hecate/reckondb/`)
2. **Identity** - Keypair (`~/.hecate/identity.pem`)
3. **Configuration** - Config file (`~/.hecate/config.json`)

**Optional:**
- **SQLite** - Read models (can be rebuilt from events)
- **Logs** - For audit/debugging

### Backup Script

```bash
#!/bin/bash
# /usr/local/bin/hecate-backup.sh

BACKUP_DIR="/backup/hecate/$(date +%Y%m%d_%H%M%S)"
DATA_DIR="/var/lib/hecate"

mkdir -p "$BACKUP_DIR"

# Stop hecate (optional, ensures consistency)
systemctl stop hecate

# Backup critical data
cp -r "$DATA_DIR/reckondb" "$BACKUP_DIR/"
cp "$DATA_DIR/identity.pem" "$BACKUP_DIR/"
cp "$DATA_DIR/config.json" "$BACKUP_DIR/"

# Optional: Backup read models
cp "$DATA_DIR"/*.db "$BACKUP_DIR/" 2>/dev/null || true

# Restart hecate
systemctl start hecate

# Compress backup
tar -czf "$BACKUP_DIR.tar.gz" -C "$BACKUP_DIR/.." "$(basename "$BACKUP_DIR")"
rm -rf "$BACKUP_DIR"

echo "Backup complete: $BACKUP_DIR.tar.gz"
```

**Cron Schedule:**

```cron
# Backup daily at 2 AM
0 2 * * * /usr/local/bin/hecate-backup.sh
```

### Recovery Procedure

**1. Stop Hecate**

```bash
systemctl stop hecate
```

**2. Restore Data**

```bash
BACKUP_FILE="/backup/hecate/20260201_020000.tar.gz"
DATA_DIR="/var/lib/hecate"

# Clear existing data
rm -rf "$DATA_DIR/reckondb"
rm -f "$DATA_DIR/identity.pem"
rm -f "$DATA_DIR"/*.db

# Extract backup
tar -xzf "$BACKUP_FILE" -C "$DATA_DIR" --strip-components=1
```

**3. Rebuild Read Models (if not restored)**

```bash
# Start hecate - it will rebuild SQLite from events
systemctl start hecate

# Monitor rebuild progress
tail -f /var/lib/hecate/logs/hecate.log
```

**4. Verify**

```bash
curl http://localhost:4444/health
```

### Disaster Recovery

**Scenario: Complete Data Loss**

If only ReckonDB is backed up:

1. Restore ReckonDB
2. Restart hecate
3. All SQLite read models rebuild automatically from events
4. Mesh projections replay and republish facts

**Recovery Time:**
- 10K events: ~30 seconds
- 100K events: ~5 minutes
- 1M events: ~30 minutes

---

## Upgrading

### Version Compatibility

| Upgrade Type | Compatibility | Procedure |
|--------------|---------------|-----------|
| Patch (0.1.x → 0.1.y) | Backward compatible | Hot swap |
| Minor (0.x → 0.y) | Backward compatible | Restart required |
| Major (x → y) | May break | Migration required |

### Upgrade Procedure (Minor/Patch)

**1. Backup Data**

```bash
/usr/local/bin/hecate-backup.sh
```

**2. Download New Version**

```bash
VERSION="0.2.0"
curl -LO "https://github.com/hecate-social/hecate-daemon/releases/download/v${VERSION}/hecate-linux-amd64.tar.gz"
```

**3. Stop Hecate**

```bash
systemctl stop hecate
```

**4. Replace Binary**

```bash
tar -xzf hecate-linux-amd64.tar.gz -C /tmp
sudo cp /tmp/hecate /usr/local/bin/hecate
sudo chmod +x /usr/local/bin/hecate
```

**5. Start Hecate**

```bash
systemctl start hecate
```

**6. Verify**

```bash
curl http://localhost:4444/health
hecate version
```

### Rollback Procedure

**1. Stop Hecate**

```bash
systemctl stop hecate
```

**2. Restore Old Binary**

```bash
sudo cp /backup/hecate-old /usr/local/bin/hecate
```

**3. Restore Data (if needed)**

```bash
tar -xzf /backup/hecate/20260201_020000.tar.gz -C /var/lib/hecate --strip-components=1
```

**4. Start Hecate**

```bash
systemctl start hecate
```

---

## Troubleshooting

### Common Issues

#### Issue: Hecate Won't Start

**Symptoms:**
```
systemctl status hecate
● hecate.service - Macula Hecate Daemon
   Active: failed
```

**Diagnosis:**

```bash
# Check logs
journalctl -u hecate -n 50

# Check port availability
sudo lsof -i :4444

# Check permissions
ls -la /var/lib/hecate
```

**Solutions:**

- **Port in use:** Change `HECATE_API_PORT` or stop conflicting service
- **Permission denied:** `chown hecate:hecate /var/lib/hecate`
- **Data corruption:** Restore from backup

#### Issue: High Projection Lag

**Symptoms:**
```
Query results stale, projection_lag_ms > 1000
```

**Diagnosis:**

```bash
# Check subscriber message queue
# (Requires Erlang observer or recon)

# Check SQLite write performance
sqlite3 /var/lib/hecate/query_capabilities.db ".timer on" "SELECT count(*) FROM capabilities;"
```

**Solutions:**

- **SQLite slow writes:** Enable WAL mode
  ```bash
  sqlite3 /var/lib/hecate/query_capabilities.db "PRAGMA journal_mode=WAL;"
  ```

- **High event rate:** Increase batch size in config
  ```json
  "reckondb": {
    "batch_size": 100
  }
  ```

- **CPU saturated:** Reduce load or scale vertically

#### Issue: Mesh Connection Fails

**Symptoms:**
```
error: mesh_connection_failed
```

**Diagnosis:**

```bash
# Check network connectivity
curl -v https://boot.macula.io:4433

# Check DNS resolution
dig boot.macula.io

# Check firewall
sudo iptables -L -n | grep 4433
```

**Solutions:**

- **Firewall blocking:** Allow outbound on port 4433
  ```bash
  sudo ufw allow out 4433/udp
  ```

- **Bootstrap node down:** Use alternate bootstrap node
  ```json
  "mesh": {
    "bootstrap": ["boot2.macula.io:4433"]
  }
  ```

- **Certificate issues:** Update CA certificates
  ```bash
  sudo update-ca-certificates
  ```

#### Issue: High Memory Usage

**Symptoms:**
```
Process using > 2GB RAM
```

**Diagnosis:**

```bash
# Check memory usage
ps aux | grep hecate

# Check aggregate count
# (Requires internal metrics)
```

**Solutions:**

- **Too many aggregates in memory:** Implement eviction policy (future)
- **Memory leak:** Restart daemon, report issue
- **Large events:** Reduce event payload sizes

### Log Analysis

**Find Errors:**

```bash
grep ERROR /var/lib/hecate/logs/hecate.log
```

**Find Slow Commands:**

```bash
grep "duration_ms.*[0-9]\{4,\}" /var/lib/hecate/logs/hecate.log
```

**Find Failed RPC Calls:**

```bash
grep "rpc.*status.*failure" /var/lib/hecate/logs/hecate.log
```

### Performance Tuning

**Increase Throughput:**

```json
{
  "storage": {
    "reckondb": {
      "batch_size": 100,
      "batch_timeout_ms": 10
    },
    "sqlite": {
      "journal_mode": "wal",
      "synchronous": "normal"
    }
  }
}
```

**Reduce Latency:**

```json
{
  "storage": {
    "reckondb": {
      "batch_size": 1,
      "fsync": false  // WARNING: Risk of data loss
    },
    "sqlite": {
      "synchronous": "off"  // WARNING: Risk of corruption
    }
  }
}
```

**Balance (Recommended for Production):**

```json
{
  "storage": {
    "reckondb": {
      "batch_size": 50,
      "batch_timeout_ms": 5,
      "fsync": true
    },
    "sqlite": {
      "journal_mode": "wal",
      "synchronous": "normal"
    }
  }
}
```

---

## Support

**Documentation:**
- GitHub: https://github.com/hecate-social/hecate-daemon
- Guides: https://hecate-social.github.io/hecate-daemon/

**Community:**
- Discord: https://discord.gg/macula
- Forum: https://discuss.macula.io

**Commercial Support:**
- Email: support@macula.io
- SLA: Available for enterprise customers
