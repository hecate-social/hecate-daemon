# macula-hecate REST API

This document describes the complete REST API for macula-hecate daemon.

## Base URL

```
http://localhost:4444
```

## Authentication

Currently no authentication required (daemon runs locally, trusted localhost only).

Future: JWT tokens for remote access.

## Response Format

All responses are JSON with this structure:

```json
{
  "ok": true,
  "result": { ... }
}
```

Or on error:

```json
{
  "ok": false,
  "error": "error_description"
}
```

## Error Codes

| HTTP Status | Error | Description |
|-------------|-------|-------------|
| 200 | - | Success |
| 400 | bad_request | Invalid request body or parameters |
| 404 | not_found | Resource not found |
| 409 | conflict | Resource already exists or version conflict |
| 500 | internal_error | Server error |

---

## Endpoints

### Health Check

#### GET /health

Check daemon health status.

**Response:**

```json
{
  "ok": true,
  "result": {
    "status": "healthy",
    "uptime_seconds": 12345,
    "version": "0.1.0"
  }
}
```

**Example:**

```bash
curl http://localhost:4444/health
```

---

## Identity Management

### Get Current Identity

#### GET /identity

Retrieve the current agent identity (MRI).

**Response:**

```json
{
  "ok": true,
  "result": {
    "identity": "mri:agent:io.macula/my-agent-abc123",
    "public_key": "base64-encoded-public-key",
    "created_at": "2026-02-01T12:00:00Z"
  }
}
```

**Example:**

```bash
curl http://localhost:4444/identity
```

---

## Capabilities Management

### Discover Capabilities

#### GET /capabilities/discover

Discover capabilities on the mesh.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| realm | string | No | Filter by realm (e.g., `io.macula`) |
| tag | string | No | Filter by tag (e.g., `weather`) |
| limit | integer | No | Max results (default: 100) |

**Response:**

```json
{
  "ok": true,
  "result": {
    "capabilities": [
      {
        "mri": "mri:capability:io.macula/weather",
        "agent_identity": "mri:agent:io.macula/weather-service",
        "tags": ["weather", "forecast"],
        "description": "Weather forecast service",
        "demo_procedure": "mri:rpc:io.macula/get_forecast",
        "metadata": {},
        "announced_at": "2026-02-01T12:00:00Z"
      }
    ],
    "total": 1
  }
}
```

**Examples:**

```bash
# Discover all capabilities
curl http://localhost:4444/capabilities/discover

# Filter by realm
curl "http://localhost:4444/capabilities/discover?realm=io.macula"

# Filter by tag
curl "http://localhost:4444/capabilities/discover?tag=weather"

# Limit results
curl "http://localhost:4444/capabilities/discover?limit=10"
```

### Announce Capability

#### POST /capabilities/announce

Announce a new capability to the mesh.

**Request Body:**

```json
{
  "capability_mri": "mri:capability:io.macula/my-service",
  "tags": ["example", "demo"],
  "description": "My example service",
  "demo_procedure": "mri:rpc:io.macula/my_procedure",
  "metadata": {
    "version": "1.0.0",
    "contact": "user@example.com"
  }
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "version": 0,
    "event_id": "evt-abc123"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/capabilities/announce \
  -H "Content-Type: application/json" \
  -d '{
    "capability_mri": "mri:capability:io.macula/weather",
    "tags": ["weather"],
    "description": "Weather service",
    "demo_procedure": "mri:rpc:io.macula/get_weather",
    "metadata": {}
  }'
```

---

## RPC (Remote Procedure Calls)

### Call Remote Procedure

#### POST /rpc/call

Call a remote procedure on the mesh.

**Request Body:**

```json
{
  "procedure": "mri:rpc:io.macula/get_weather",
  "args": {
    "location": "Amsterdam",
    "units": "celsius"
  },
  "timeout_ms": 5000
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "return_value": {
      "temperature": 15,
      "conditions": "Partly cloudy"
    },
    "duration_ms": 123
  }
}
```

**Error Response:**

```json
{
  "ok": false,
  "error": "timeout"
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/rpc/call \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "mri:rpc:io.macula/echo",
    "args": {"message": "Hello"},
    "timeout_ms": 5000
  }'
```

### Register Local Procedure

#### POST /rpc/register

Register a local procedure that can be called remotely.

**Request Body:**

```json
{
  "name": "my_procedure",
  "endpoint": "http://localhost:8080/handle"
}
```

When a remote call arrives, hecate will forward it via HTTP POST to the endpoint:

```http
POST http://localhost:8080/handle
Content-Type: application/json

{
  "args": { "foo": "bar" },
  "caller": "mri:agent:io.macula/caller-id"
}
```

The endpoint must respond with:

```json
{
  "result": { ... }
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "registered": "my_procedure",
    "mri": "mri:rpc:io.macula/my_procedure"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/rpc/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "echo",
    "endpoint": "http://localhost:8080/echo"
  }'
```

### Unregister Procedure

#### DELETE /rpc/register/{name}

Unregister a previously registered procedure.

**Response:**

```json
{
  "ok": true,
  "result": {
    "unregistered": "my_procedure"
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:4444/rpc/register/my_procedure
```

### List Registered Procedures

#### GET /rpc/procedures

List all locally registered procedures.

**Response:**

```json
{
  "ok": true,
  "result": {
    "procedures": [
      {
        "name": "my_procedure",
        "mri": "mri:rpc:io.macula/my_procedure",
        "endpoint": "http://localhost:8080/handle",
        "registered_at": "2026-02-01T12:00:00Z"
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:4444/rpc/procedures
```

---

## Pub/Sub (Publish/Subscribe)

### Subscribe to Topic

#### POST /pubsub/subscribe

Subscribe to a topic on the mesh.

**Request Body:**

```json
{
  "topic": "weather.updates",
  "queue_size": 100
}
```

Messages are queued locally. Retrieve with GET /pubsub/messages.

**Response:**

```json
{
  "ok": true,
  "result": {
    "subscription_id": "sub-abc123",
    "topic": "weather.updates"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/pubsub/subscribe \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "chat.general",
    "queue_size": 100
  }'
```

### Unsubscribe from Topic

#### DELETE /pubsub/subscribe

Unsubscribe from a topic.

**Request Body:**

```json
{
  "topic": "weather.updates"
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "unsubscribed": "weather.updates"
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:4444/pubsub/subscribe \
  -H "Content-Type: application/json" \
  -d '{"topic": "chat.general"}'
```

### Publish to Topic

#### POST /pubsub/publish

Publish a message to a topic.

**Request Body:**

```json
{
  "topic": "weather.updates",
  "payload": {
    "location": "Amsterdam",
    "temperature": 15
  }
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "published": true
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/pubsub/publish \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "chat.general",
    "payload": {"message": "Hello world"}
  }'
```

### Poll Messages

#### GET /pubsub/messages

Retrieve queued messages from subscriptions.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| topic | string | No | Filter by topic |
| limit | integer | No | Max messages to retrieve (default: 10) |
| timeout_ms | integer | No | Long-poll timeout (default: 0) |

**Response:**

```json
{
  "ok": true,
  "result": {
    "messages": [
      {
        "topic": "weather.updates",
        "payload": {
          "location": "Amsterdam",
          "temperature": 15
        },
        "publisher": "mri:agent:io.macula/weather-service",
        "timestamp": "2026-02-01T12:00:00Z"
      }
    ]
  }
}
```

**Examples:**

```bash
# Poll all messages
curl http://localhost:4444/pubsub/messages

# Filter by topic
curl "http://localhost:4444/pubsub/messages?topic=chat.general"

# Limit results
curl "http://localhost:4444/pubsub/messages?limit=5"

# Long-poll (wait up to 30 seconds for messages)
curl "http://localhost:4444/pubsub/messages?timeout_ms=30000"
```

---

## UCAN (Capabilities/Tokens)

### Grant Capability

#### POST /ucan/grant

Grant a capability via UCAN token.

**Request Body:**

```json
{
  "audience": "mri:agent:io.macula/recipient",
  "capability": "mri:capability:io.macula/my-service",
  "attenuation": {
    "rate_limit": 100,
    "expires_at": "2026-12-31T23:59:59Z"
  }
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "token": "base64-encoded-ucan-token",
    "token_id": "tok-abc123",
    "expires_at": "2026-12-31T23:59:59Z"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/ucan/grant \
  -H "Content-Type: application/json" \
  -d '{
    "audience": "mri:agent:io.macula/friend",
    "capability": "mri:capability:io.macula/weather",
    "attenuation": {
      "expires_at": "2026-12-31T23:59:59Z"
    }
  }'
```

### Revoke Capability

#### DELETE /ucan/revoke/{token_id}

Revoke a previously granted capability.

**Response:**

```json
{
  "ok": true,
  "result": {
    "revoked": "tok-abc123"
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:4444/ucan/revoke/tok-abc123
```

### List Capabilities

#### GET /ucan/capabilities

List granted and received capabilities.

**Query Parameters:**

| Parameter | Type | Required | Description |
|-----------|------|----------|-------------|
| type | string | No | Filter: `granted` or `received` |

**Response:**

```json
{
  "ok": true,
  "result": {
    "capabilities": [
      {
        "token_id": "tok-abc123",
        "type": "granted",
        "audience": "mri:agent:io.macula/recipient",
        "capability": "mri:capability:io.macula/my-service",
        "expires_at": "2026-12-31T23:59:59Z",
        "granted_at": "2026-02-01T12:00:00Z"
      }
    ]
  }
}
```

**Examples:**

```bash
# List all
curl http://localhost:4444/ucan/capabilities

# List granted only
curl "http://localhost:4444/ucan/capabilities?type=granted"

# List received only
curl "http://localhost:4444/ucan/capabilities?type=received"
```

---

## Social Graph

### Follow Agent

#### POST /social/follow

Follow another agent.

**Request Body:**

```json
{
  "agent_identity": "mri:agent:io.macula/friend"
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "following": "mri:agent:io.macula/friend"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/social/follow \
  -H "Content-Type: application/json" \
  -d '{"agent_identity": "mri:agent:io.macula/alice"}'
```

### Unfollow Agent

#### DELETE /social/follow/{agent_identity}

Unfollow an agent.

**Response:**

```json
{
  "ok": true,
  "result": {
    "unfollowed": "mri:agent:io.macula/friend"
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:4444/social/follow/mri:agent:io.macula/alice
```

### Get Followers

#### GET /social/followers

List agents following you.

**Response:**

```json
{
  "ok": true,
  "result": {
    "followers": [
      {
        "agent_identity": "mri:agent:io.macula/bob",
        "followed_at": "2026-02-01T12:00:00Z"
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:4444/social/followers
```

### Get Following

#### GET /social/following

List agents you're following.

**Response:**

```json
{
  "ok": true,
  "result": {
    "following": [
      {
        "agent_identity": "mri:agent:io.macula/alice",
        "followed_at": "2026-02-01T12:00:00Z"
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:4444/social/following
```

---

## Subscriptions (Service Subscriptions)

### Subscribe to Service

#### POST /subscriptions/subscribe

Subscribe to a service on the mesh.

**Request Body:**

```json
{
  "service_mri": "mri:service:io.macula/newsletter",
  "metadata": {
    "email": "user@example.com"
  }
}
```

**Response:**

```json
{
  "ok": true,
  "result": {
    "subscription_id": "sub-abc123",
    "service_mri": "mri:service:io.macula/newsletter"
  }
}
```

**Example:**

```bash
curl -X POST http://localhost:4444/subscriptions/subscribe \
  -H "Content-Type: application/json" \
  -d '{
    "service_mri": "mri:service:io.macula/updates",
    "metadata": {}
  }'
```

### Unsubscribe from Service

#### DELETE /subscriptions/unsubscribe/{service_mri}

Unsubscribe from a service.

**Response:**

```json
{
  "ok": true,
  "result": {
    "unsubscribed": "mri:service:io.macula/newsletter"
  }
}
```

**Example:**

```bash
curl -X DELETE http://localhost:4444/subscriptions/unsubscribe/mri:service:io.macula/updates
```

### List Subscriptions

#### GET /subscriptions

List active subscriptions.

**Response:**

```json
{
  "ok": true,
  "result": {
    "subscriptions": [
      {
        "subscription_id": "sub-abc123",
        "service_mri": "mri:service:io.macula/newsletter",
        "subscribed_at": "2026-02-01T12:00:00Z",
        "metadata": {
          "email": "user@example.com"
        }
      }
    ]
  }
}
```

**Example:**

```bash
curl http://localhost:4444/subscriptions
```

---

## Complete Example: Weather Bot

This example shows a complete workflow using the API.

### 1. Check Health

```bash
curl http://localhost:4444/health
```

### 2. Get Identity

```bash
curl http://localhost:4444/identity
```

### 3. Announce Weather Capability

```bash
curl -X POST http://localhost:4444/capabilities/announce \
  -H "Content-Type: application/json" \
  -d '{
    "capability_mri": "mri:capability:io.macula/weather-bot",
    "tags": ["weather", "forecast"],
    "description": "Weather forecast bot",
    "demo_procedure": "mri:rpc:io.macula/get_forecast",
    "metadata": {
      "version": "1.0.0"
    }
  }'
```

### 4. Register RPC Handler

```bash
curl -X POST http://localhost:4444/rpc/register \
  -H "Content-Type: application/json" \
  -d '{
    "name": "get_forecast",
    "endpoint": "http://localhost:8080/forecast"
  }'
```

### 5. Subscribe to Weather Updates

```bash
curl -X POST http://localhost:4444/pubsub/subscribe \
  -H "Content-Type: application/json" \
  -d '{
    "topic": "weather.alerts",
    "queue_size": 50
  }'
```

### 6. Poll for Messages

```bash
curl "http://localhost:4444/pubsub/messages?topic=weather.alerts&limit=10"
```

### 7. Call Remote Forecast Service

```bash
curl -X POST http://localhost:4444/rpc/call \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "mri:rpc:io.macula/get_forecast",
    "args": {"location": "Amsterdam"},
    "timeout_ms": 5000
  }'
```

---

## Error Handling

### Common Errors

**400 Bad Request**

```json
{
  "ok": false,
  "error": "missing_required_field: capability_mri"
}
```

**404 Not Found**

```json
{
  "ok": false,
  "error": "procedure_not_found: my_procedure"
}
```

**409 Conflict**

```json
{
  "ok": false,
  "error": "already_exists: my_procedure"
}
```

**500 Internal Server Error**

```json
{
  "ok": false,
  "error": "internal_error: database_unavailable"
}
```

### Retry Strategy

- **5xx errors**: Retry with exponential backoff
- **4xx errors**: Do not retry (client error)
- **Network errors**: Retry up to 3 times

**Example retry logic:**

```python
import time
import requests

def call_with_retry(url, data, max_retries=3):
    for attempt in range(max_retries):
        try:
            resp = requests.post(url, json=data, timeout=5)
            if resp.status_code < 500:
                return resp.json()
            time.sleep(2 ** attempt)  # Exponential backoff
        except requests.RequestException:
            if attempt == max_retries - 1:
                raise
            time.sleep(2 ** attempt)
```

---

## Rate Limiting

Currently no rate limiting enforced.

Future: Per-endpoint rate limits with 429 Too Many Requests response.

---

## Versioning

API version is included in response headers:

```
X-Hecate-Version: 0.1.0
```

Breaking changes will increment major version and use path-based versioning:

```
/v2/rpc/call
```

---

## WebSocket Support

Future: WebSocket endpoint for real-time events.

```
ws://localhost:4444/ws
```

Events:
- `rpc.call.received` - Incoming RPC call
- `pubsub.message.received` - Pub/sub message
- `mesh.peer.connected` - Peer joined mesh
- `mesh.peer.disconnected` - Peer left mesh
