# PLAN: retract_capability

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** PLAN_ANNOUNCE_CAPABILITY.md
**Domain:** Capabilities (Command Service)

---

## Business Goal

Enable agents to **remove capabilities from the network** when they are:
- Deprecated (replaced by newer version)
- No longer maintained
- Temporarily unavailable
- Shutting down permanently

**Use Case:** Alice shuts down her weather service. She should retract the capability so other agents don't try to call it.

---

## Event Storm

### Command

**Name:** `retract_capability_v1`
**Module:** `src/retract_capability/retract_capability_v1.erl`

**Structure:**
```erlang
-record(retract_capability_v1, {
    capability_mri :: binary(),        % "mri:capability:io.macula.alice/weather-forecast"
    agent_identity :: binary(),        % "mri:agent:io.macula.alice/claude-assistant"
    reason :: binary(),                % Optional: "Deprecated", "Shutting down", etc.
    retracted_by :: binary()           % UCAN token
}).
```

**Validation Rules:**
1. `capability_mri` MUST exist (already announced)
2. `agent_identity` MUST match original announcer (only owner can retract)
3. `retracted_by` MUST be valid UCAN token
4. UCAN token MUST grant capability to retract for this agent

**Example:**
```erlang
Command = #retract_capability_v1{
    capability_mri = <<"mri:capability:io.macula.alice/weather-forecast">>,
    agent_identity = <<"mri:agent:io.macula.alice/claude-assistant">>,
    reason = <<"Deprecated - use weather-forecast-v2 instead">>,
    retracted_by = <<"eyJhbGc...UCAN_TOKEN">>
}.
```

---

### Event

**Name:** `capability_retracted_v1`
**Module:** `src/retract_capability/capability_retracted_v1.erl`

**Structure:**
```erlang
-record(capability_retracted_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    reason :: binary() | undefined,
    retracted_at :: integer()          % Unix timestamp (milliseconds)
}).
```

---

### Handler

**Name:** `maybe_retract_capability`
**Module:** `src/retract_capability/maybe_retract_capability.erl`

**Logic:**
1. Validate command structure
2. Check capability exists
3. Check capability is not already retracted
4. Check agent identity matches announcer
5. Validate UCAN token
6. Create event

**Pseudocode:**
```erlang
-module(maybe_retract_capability).
-export([handle/1]).

handle(#retract_capability_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_capability_exists(Cmd#retract_capability_v1.capability_mri) end,
        fun() -> validate_not_already_retracted(Cmd#retract_capability_v1.capability_mri) end,
        fun() -> validate_ownership(Cmd) end,
        fun() -> validate_ucan(Cmd#retract_capability_v1.retracted_by, Cmd#retract_capability_v1.agent_identity) end
    ], fun() ->
        {ok, create_event(Cmd)}
    end).

validate_capability_exists(MRI) ->
    case query_capabilities:get_capability(MRI) of
        {ok, _} -> ok;
        {error, not_found} -> {error, <<"Capability not found">>}
    end.

validate_not_already_retracted(MRI) ->
    case query_capabilities:get_capability(MRI) of
        {ok, #{retracted := true}} -> {error, <<"Capability already retracted">>};
        {ok, #{retracted := false}} -> ok
    end.

validate_ownership(#retract_capability_v1{capability_mri = MRI, agent_identity = Agent}) ->
    case query_capabilities:get_capability(MRI) of
        {ok, #{agent_identity := Agent}} -> ok;
        {ok, #{agent_identity := _Other}} -> {error, <<"Only the original announcer can retract this capability">>}
    end.

create_event(#retract_capability_v1{} = Cmd) ->
    #capability_retracted_v1{
        capability_mri = Cmd#retract_capability_v1.capability_mri,
        agent_identity = Cmd#retract_capability_v1.agent_identity,
        reason = Cmd#retract_capability_v1.reason,
        retracted_at = erlang:system_time(millisecond)
    }.
```

---

### Projection

**Name:** `capability_retracted_v1_to_capabilities`
**Module:** `src/../query_capabilities/capability_retracted_v1_to_capabilities.erl`

**Logic:**
Mark capability as retracted (soft delete).

**Pseudocode:**
```erlang
-module(capability_retracted_v1_to_capabilities).
-export([project/1]).

project(Event) ->
    #{
        <<"capability_mri">> := MRI,
        <<"reason">> := Reason,
        <<"retracted_at">> := Time
    } = Event,

    SQL = <<"
        UPDATE capabilities
        SET retracted = true,
            retracted_reason = ?,
            retracted_at = ?
        WHERE capability_mri = ?
    ">>,

    hecate_store:execute(SQL, [Reason, Time, MRI]).
```

**Note:** Retracted capabilities:
- Are NOT deleted (keep for audit trail)
- Are marked `retracted = true`
- Do NOT appear in discovery results
- Can still be viewed in history

---

## Mesh Integration

### Topic

**Publish to:** `capability.retracted`

**Subscribers:**
- All query_capabilities services
- macula-realm (remove from UI)
- Agents following the owner (notify followers)

---

## REST API

### Endpoint

```
DELETE /capabilities/:mri
Content-Type: application/json
Authorization: Bearer <ucan-token>

{
  "reason": "Deprecated - use weather-forecast-v2 instead"
}

Response 200:
{
  "ok": true,
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
  "retracted_at": "2026-01-31T12:00:00Z"
}

Response 404:
{
  "ok": false,
  "error": "capability_not_found"
}

Response 403:
{
  "ok": false,
  "error": "unauthorized",
  "message": "Only the original announcer can retract this capability"
}

Response 409:
{
  "ok": false,
  "error": "already_retracted"
}
```

---

## Success Criteria

- [ ] Only owner can retract
- [ ] Retracted capabilities hidden from discovery
- [ ] Retraction published to mesh
- [ ] Read model updated (retracted = true)
- [ ] REST API works
- [ ] UI removes capability from active list
- [ ] History preserved (soft delete, not hard delete)

---

**Related Plans:**
- [PLAN_ANNOUNCE_CAPABILITY.md](PLAN_ANNOUNCE_CAPABILITY.md)
- [PLAN_UPDATE_CAPABILITY.md](PLAN_UPDATE_CAPABILITY.md)
- [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
