# Mesh Integration

## Overview

The `hecate_mesh` app integrates Hecate daemon with the Macula Mesh network for distributed event pub/sub.

## Architecture

```
Domain Events → hecate_mesh_publisher → Mesh DHT → hecate_mesh_subscriber → Projections
```

### Components

**1. hecate_mesh_client** (gen_server)
- Manages connection to Macula mesh
- Provides publish/subscribe API
- Auto-reconnects on disconnect

**2. hecate_mesh_publisher** (gen_server)
- Publishes domain events to mesh topics
- Maps event types to mesh topics
- Handles publish failures gracefully

**3. hecate_mesh_subscriber** (gen_server)
- Subscribes to mesh event topics
- Routes events to appropriate projections
- Handles projection errors

## Topic Mapping

Events are published to topics based on their type:

| Event Type | Mesh Topic |
|------------|------------|
| `capability_announced_v1` | `hecate.capability.announced` |
| `capability_updated_v1` | `hecate.capability.updated` |
| `capability_retracted_v1` | `hecate.capability.retracted` |
| `rpc_call_tracked_v1` | `hecate.rpc.tracked` |
| `dispute_flagged_v1` | `hecate.dispute.flagged` |
| `dispute_resolved_v1` | `hecate.dispute.resolved` |
| `agent_followed_v1` | `hecate.social.followed` |
| `agent_unfollowed_v1` | `hecate.social.unfollowed` |

## Configuration

Set in `hecate_mesh.app.src`:

```erlang
{env, [
    {bootstrap_nodes, ["https://boot.macula.io:443"]},
    {realm, <<"io.macula">>},
    {agent_identity, <<"mri:agent:io.macula/hecate">>}
]}
```

Or override at runtime:

```erlang
application:set_env(hecate_mesh, bootstrap_nodes, ["custom.node:4433"]).
application:set_env(hecate_mesh, realm, <<"custom.realm">>).
```

## Usage

### Publishing Events (from command handlers)

```erlang
%% In command handler after creating event
{ok, Events} = maybe_announce_capability:handle(Cmd),

%% Publish each event to mesh
lists:foreach(fun(EventMap) ->
    EventType = maps:get(event_type, EventMap),
    hecate_mesh:publish_event(EventType, EventMap)
end, Events).
```

### Subscribing to Events (in query services)

```erlang
%% Query services auto-subscribe on startup
%% Events are routed to projections automatically

%% Manual subscription:
hecate_mesh:subscribe_to_events().
```

### Direct Mesh Access

```erlang
%% Get mesh client
{ok, Client} = hecate_mesh:get_client().

%% Use macula API directly if needed
%% (when actual macula integration is complete)
```

## Event Flow Example

```
1. HTTP POST /capabilities/announce
   ↓
2. hecate_api_capabilities handler
   ↓
3. maybe_announce_capability (command handler)
   ↓
4. Returns [capability_announced_v1 event]
   ↓
5. Store in ReckonDB (local)
   ↓
6. hecate_mesh:publish_event("capability_announced_v1", EventData)
   ↓
7. hecate_mesh_publisher → topic: hecate.capability.announced
   ↓
8. Macula mesh DHT
   ↓
9. hecate_mesh_subscriber (on other hecate instances)
   ↓
10. capability_announced_v1_to_capabilities:project/2
    ↓
11. SQLite read model updated
```

## Current Status

✅ **Implemented:**
- Mesh client connection via `macula:connect_local/1`
- Event publisher with topic mapping via `macula:publish/3`
- Event subscriber with `macula:subscribe/3` and projection routing
- Configuration and supervision tree
- Automatic reconnection on disconnect (process monitoring)
- Connection health check via `hecate_mesh:is_connected/0`

🔄 **TODO:**
- Add metrics and telemetry
- Add connection pooling for high-volume publishing
- Add circuit breaker for mesh unavailability

## Multi-Instance Deployment

When running multiple hecate instances:

1. **Each instance** has its own ReckonDB stores (embedded mode)
2. **Events are published** to mesh DHT for distribution
3. **All instances** receive events and update their local read models
4. **Read models** are eventually consistent across instances
5. **Queries** are local (no network hop) for fast response

This enables:
- Horizontal scaling of query load
- Geographic distribution
- Fault tolerance (no single point of failure)

## Security Considerations

- Events published to mesh are **public** within the realm
- Use UCAN capabilities for authorization
- Event payloads should not contain secrets
- Consider encryption for sensitive event data

## Testing

```erlang
%% Start hecate with mesh enabled
rebar3 shell

%% Publish test event
hecate_mesh:publish_event(<<"test_event_v1">>, #{test => <<"data">>}).

%% Check logs for publish confirmation
```

## Troubleshooting

**Connection fails:**
- Check bootstrap node is reachable
- Verify network allows UDP/QUIC traffic
- Check firewall rules

**Events not received:**
- Verify subscription was successful
- Check topic names match exactly
- Look for projection errors in logs

**High latency:**
- Check network connectivity
- Consider local caching strategies
- Monitor mesh DHT health
