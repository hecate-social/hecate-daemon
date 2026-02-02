# PLAN: track_rpc_call

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** None (foundational for reputation system)

---

## Business Goal

Enable agents to **record RPC interactions** for reputation tracking. When an agent calls another agent's RPC procedure, both parties can publish a tracking event that includes:
- Call result (success, failure, timeout)
- Response time
- Error details (if failed)

These events are:
- Published to the mesh (transparency)
- Verified by signatures (trust)
- Projected into reputation tables (analytics)
- Used to compute agent reputation scores

This is the **foundation of the reputation system** - reputation is derived from actual verified RPC interactions, not manual ratings.

---

## Event Storm

### Command

**Name:** `track_rpc_call_v1`
**Module:** `src/track_rpc_call/track_rpc_call_v1.erl`

**Structure:**
```erlang
-record(track_rpc_call_v1, {
    call_id :: binary(),               % UUID v7 for this RPC call
    caller_identity :: binary(),       % "mri:agent:io.macula.bob/gpt-assistant"
    provider_identity :: binary(),     % "mri:agent:io.macula.alice/claude-assistant"
    capability_mri :: binary(),        % "mri:capability:io.macula.alice/weather-forecast"
    procedure_name :: binary(),        % "io.macula.alice.get_weather"
    call_result :: atom(),             % success | failure | timeout
    response_time_ms :: integer(),     % Milliseconds to complete
    error_details :: binary() | undefined,  % Error message if failed
    metadata :: map(),                 % Optional: request_id, trace_id, etc.
    tracked_by :: binary()             % UCAN token (caller OR provider can track)
}).
```

**Validation Rules:**
1. `call_id` MUST be valid UUID v7 format
2. `caller_identity` MUST be valid MRI format (agent)
3. `provider_identity` MUST be valid MRI format (agent)
4. `capability_mri` MUST be valid MRI format (capability)
5. `procedure_name` MUST be non-empty binary
6. `call_result` MUST be one of: `success`, `failure`, `timeout`
7. `response_time_ms` MUST be non-negative integer
8. If `call_result` = `failure`, `error_details` SHOULD be provided
9. `tracked_by` MUST be valid UCAN token
10. UCAN token MUST prove identity is EITHER caller OR provider (not third party)

**Example (Successful Call):**
```erlang
Command = #track_rpc_call_v1{
    call_id = <<"01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f">>,
    caller_identity = <<"mri:agent:io.macula.bob/gpt-assistant">>,
    provider_identity = <<"mri:agent:io.macula.alice/claude-assistant">>,
    capability_mri = <<"mri:capability:io.macula.alice/weather-forecast">>,
    procedure_name = <<"io.macula.alice.get_weather">>,
    call_result = success,
    response_time_ms = 250,
    error_details = undefined,
    metadata = #{
        <<"request_id">> => <<"req-12345">>,
        <<"location">> => <<"Paris, France">>
    },
    tracked_by = <<"eyJhbGc...UCAN_TOKEN">>  % Bob's token
}.
```

**Example (Failed Call):**
```erlang
Command = #track_rpc_call_v1{
    call_id = <<"01935d2b-4f7e-8c9d-0e1f-2a3b4c5d6e7f">>,
    caller_identity = <<"mri:agent:io.macula.bob/gpt-assistant">>,
    provider_identity = <<"mri:agent:io.macula.alice/claude-assistant">>,
    capability_mri = <<"mri:capability:io.macula.alice/weather-forecast">>,
    procedure_name = <<"io.macula.alice.get_weather">>,
    call_result = failure,
    response_time_ms = 5000,
    error_details = <<"Invalid location: 'Mars' not found in database">>,
    metadata = #{
        <<"request_id">> => <<"req-12346">>,
        <<"location">> => <<"Mars">>
    },
    tracked_by = <<"eyJhbGc...UCAN_TOKEN">>  % Alice's token (provider can also track failures)
}.
```

---

### Handler

**Name:** `maybe_track_rpc_call`
**Module:** `src/track_rpc_call/maybe_track_rpc_call.erl`

**Logic:**
1. Validate command structure
2. Validate all MRI formats
3. Validate UCAN token
4. **Verify tracked_by is caller OR provider** (not third party)
5. Check for duplicate tracking (same call_id already tracked)
6. If all valid, create event
7. If invalid, return error

**Trust Model:**

**CRITICAL:** Both caller and provider can publish tracking events. If they disagree on the result:
- Mark the call as **disputed**
- Exclude from reputation calculation
- Flag for investigation (future: dispute resolution mechanism)

**Pseudocode:**
```erlang
-module(maybe_track_rpc_call).
-export([handle/1]).

handle(#track_rpc_call_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_uuid_v7(Cmd#track_rpc_call_v1.call_id) end,
        fun() -> validate_mri_format(Cmd#track_rpc_call_v1.caller_identity) end,
        fun() -> validate_mri_format(Cmd#track_rpc_call_v1.provider_identity) end,
        fun() -> validate_mri_format(Cmd#track_rpc_call_v1.capability_mri) end,
        fun() -> validate_call_result(Cmd#track_rpc_call_v1.call_result) end,
        fun() -> validate_response_time(Cmd#track_rpc_call_v1.response_time_ms) end,
        fun() -> validate_ucan_is_party(Cmd) end,
        fun() -> check_not_duplicate(Cmd#track_rpc_call_v1.call_id) end
    ], fun() ->
        {ok, create_event(Cmd)}
    end).

validate_uuid_v7(CallId) when is_binary(CallId) ->
    % UUID v7 format: xxxxxxxx-xxxx-7xxx-yxxx-xxxxxxxxxxxx
    case re:run(CallId, <<"^[0-9a-f]{8}-[0-9a-f]{4}-7[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$">>, [{capture, none}]) of
        match -> ok;
        nomatch -> {error, {invalid_uuid_v7, CallId}}
    end;
validate_uuid_v7(_) ->
    {error, call_id_must_be_binary}.

validate_call_result(success) -> ok;
validate_call_result(failure) -> ok;
validate_call_result(timeout) -> ok;
validate_call_result(Other) ->
    {error, {invalid_call_result, Other}}.

validate_response_time(Time) when is_integer(Time), Time >= 0 -> ok;
validate_response_time(_) -> {error, response_time_must_be_non_negative_integer}.

validate_ucan_is_party(#track_rpc_call_v1{} = Cmd) ->
    % Verify UCAN token proves identity is CALLER or PROVIDER
    case hecate_ucan:verify(Cmd#track_rpc_call_v1.tracked_by) of
        {ok, Claims} ->
            Identity = extract_identity_from_claims(Claims),
            IsCaller = (Identity =:= Cmd#track_rpc_call_v1.caller_identity),
            IsProvider = (Identity =:= Cmd#track_rpc_call_v1.provider_identity),

            if
                IsCaller orelse IsProvider -> ok;
                true -> {error, tracked_by_must_be_caller_or_provider}
            end;
        {error, Reason} ->
            {error, {ucan_invalid, Reason}}
    end.

check_not_duplicate(CallId) ->
    % Check if this call_id was already tracked
    case hecate_store:exists(<<"rpc_call_events">>, CallId) of
        false -> ok;
        true ->
            % Already tracked - check if it's a conflicting report
            {ok, [ExistingEvent]} = hecate_store:query(
                <<"SELECT * FROM rpc_call_events WHERE call_id = ?">>,
                [CallId]
            ),

            % If same result from same party, ignore (idempotent)
            % If different result, mark as disputed
            {error, {duplicate_tracking, ExistingEvent}}
    end.

create_event(#track_rpc_call_v1{} = Cmd) ->
    #rpc_call_tracked_v1{
        call_id = Cmd#track_rpc_call_v1.call_id,
        caller_identity = Cmd#track_rpc_call_v1.caller_identity,
        provider_identity = Cmd#track_rpc_call_v1.provider_identity,
        capability_mri = Cmd#track_rpc_call_v1.capability_mri,
        procedure_name = Cmd#track_rpc_call_v1.procedure_name,
        call_result = Cmd#track_rpc_call_v1.call_result,
        response_time_ms = Cmd#track_rpc_call_v1.response_time_ms,
        error_details = Cmd#track_rpc_call_v1.error_details,
        metadata = Cmd#track_rpc_call_v1.metadata,
        tracked_at = erlang:system_time(second),
        tracked_by_identity = extract_identity_from_ucan(Cmd#track_rpc_call_v1.tracked_by)
    }.
```

---

### Event

**Name:** `rpc_call_tracked_v1`
**Module:** `src/track_rpc_call/rpc_call_tracked_v1.erl`

**Structure:**
```erlang
-record(rpc_call_tracked_v1, {
    call_id :: binary(),
    caller_identity :: binary(),
    provider_identity :: binary(),
    capability_mri :: binary(),
    procedure_name :: binary(),
    call_result :: atom(),             % success | failure | timeout
    response_time_ms :: integer(),
    error_details :: binary() | undefined,
    metadata :: map(),
    tracked_at :: integer(),           % Unix timestamp
    tracked_by_identity :: binary()    % Who tracked this (caller or provider)
}).
```

**Mesh Topic:** `"rpc.call_tracked"`

**Event Signing:**
```erlang
% Both caller and provider can publish this event
EventBytes = term_to_binary(Event),
{ok, Signature} = hecate_identity:sign(EventBytes),
{ok, DID} = hecate_identity:get_did(),

PublishedEvent = #{
    <<"event">> => Event,
    <<"signature">> => Signature,
    <<"agent_did">> => DID,
    <<"event_type">> => <<"rpc_call_tracked_v1">>
}.

% Publish to mesh
hecate_mesh:publish("rpc.call_tracked", PublishedEvent).
```

**Dispute Detection:**

When a subscriber receives an RPC tracking event, check if the same `call_id` was already tracked with a different result:

```erlang
handle_rpc_tracking_event(#{<<"event">> := Event} = Payload) ->
    % Verify signature first
    case verify_signature(Payload) of
        ok ->
            % Check for existing tracking of this call_id
            case hecate_store:query(
                <<"SELECT * FROM rpc_call_events WHERE call_id = ?">>,
                [Event#rpc_call_tracked_v1.call_id]
            ) of
                {ok, []} ->
                    % First tracking - project normally
                    project_event(Event);

                {ok, [ExistingRow]} ->
                    ExistingResult = maps:get(<<"call_result">>, ExistingRow),
                    NewResult = atom_to_binary(Event#rpc_call_tracked_v1.call_result),

                    if
                        ExistingResult =:= NewResult ->
                            % Same result - ignore (idempotent)
                            lager:debug("Duplicate tracking (same result) - ignoring"),
                            ok;

                        true ->
                            % Different result - DISPUTE!
                            lager:warning("RPC call dispute detected: call_id=~s, existing=~s, new=~s",
                                [Event#rpc_call_tracked_v1.call_id, ExistingResult, NewResult]),

                            % Mark as disputed
                            mark_as_disputed(Event#rpc_call_tracked_v1.call_id),
                            ok
                    end
            end;

        {error, Reason} ->
            lager:error("Invalid signature on RPC tracking event: ~p", [Reason]),
            ignore
    end.

mark_as_disputed(CallId) ->
    SQL = <<"UPDATE rpc_call_events SET disputed = TRUE WHERE call_id = ?">>,
    hecate_store:exec(SQL, [CallId]).
```

---

### Projection

**Name:** `rpc_call_tracked_v1_to_rpc_events`
**Module:** `src/track_rpc_call/rpc_call_tracked_v1_to_rpc_events.erl`

**Target Table:** `rpc_call_events`

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS rpc_call_events (
    call_id TEXT PRIMARY KEY,
    caller_identity TEXT NOT NULL,
    provider_identity TEXT NOT NULL,
    capability_mri TEXT NOT NULL,
    procedure_name TEXT NOT NULL,
    call_result TEXT NOT NULL,         -- 'success', 'failure', 'timeout'
    response_time_ms INTEGER NOT NULL,
    error_details TEXT,
    metadata TEXT,                     -- JSON
    tracked_at INTEGER NOT NULL,
    tracked_by_identity TEXT NOT NULL,
    disputed BOOLEAN DEFAULT FALSE,    -- TRUE if conflicting reports

    INDEX idx_provider ON rpc_call_events(provider_identity),
    INDEX idx_caller ON rpc_call_events(caller_identity),
    INDEX idx_capability ON rpc_call_events(capability_mri),
    INDEX idx_tracked_at ON rpc_call_events(tracked_at DESC)
);
```

**Target Table:** `agent_reputation`

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS agent_reputation (
    agent_identity TEXT PRIMARY KEY,
    total_calls INTEGER DEFAULT 0,
    successful_calls INTEGER DEFAULT 0,
    failed_calls INTEGER DEFAULT 0,
    timeout_calls INTEGER DEFAULT 0,
    disputed_calls INTEGER DEFAULT 0,
    avg_response_time_ms REAL DEFAULT 0.0,
    success_rate REAL DEFAULT 0.0,       -- successful_calls / total_calls
    reputation_score REAL DEFAULT 0.0,   -- Computed score (0-100)
    last_call_at INTEGER,
    updated_at INTEGER NOT NULL
);
```

**Projection Logic:**
```erlang
-module(rpc_call_tracked_v1_to_rpc_events).
-export([project/2]).

project(#rpc_call_tracked_v1{} = Event, DB) ->
    % 1. Insert into rpc_call_events
    ok = insert_rpc_event(Event, DB),

    % 2. Update provider's reputation
    ok = update_provider_reputation(Event, DB),

    % 3. Update caller's stats (for analytics, not reputation)
    ok = update_caller_stats(Event, DB),

    ok.

insert_rpc_event(#rpc_call_tracked_v1{} = Event, DB) ->
    MetadataJson = jsx:encode(Event#rpc_call_tracked_v1.metadata),

    SQL = <<"
        INSERT OR IGNORE INTO rpc_call_events
            (call_id, caller_identity, provider_identity, capability_mri, procedure_name,
             call_result, response_time_ms, error_details, metadata, tracked_at, tracked_by_identity, disputed)
        VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, FALSE)
    ">>,

    esqlite3:exec(DB, SQL, [
        Event#rpc_call_tracked_v1.call_id,
        Event#rpc_call_tracked_v1.caller_identity,
        Event#rpc_call_tracked_v1.provider_identity,
        Event#rpc_call_tracked_v1.capability_mri,
        Event#rpc_call_tracked_v1.procedure_name,
        atom_to_binary(Event#rpc_call_tracked_v1.call_result),
        Event#rpc_call_tracked_v1.response_time_ms,
        Event#rpc_call_tracked_v1.error_details,
        MetadataJson,
        Event#rpc_call_tracked_v1.tracked_at,
        Event#rpc_call_tracked_v1.tracked_by_identity
    ]).

update_provider_reputation(#rpc_call_tracked_v1{} = Event, DB) ->
    % Get current reputation or create new row
    case hecate_store:query(
        <<"SELECT * FROM agent_reputation WHERE agent_identity = ?">>,
        [Event#rpc_call_tracked_v1.provider_identity]
    ) of
        {ok, []} ->
            % No reputation yet - insert
            insert_initial_reputation(Event#rpc_call_tracked_v1.provider_identity, DB);
        {ok, [_Row]} ->
            ok  % Exists
    end,

    % Update stats
    CallResult = Event#rpc_call_tracked_v1.call_result,
    ResponseTime = Event#rpc_call_tracked_v1.response_time_ms,

    SQL = <<"
        UPDATE agent_reputation
        SET
            total_calls = total_calls + 1,
            successful_calls = successful_calls + CASE WHEN ? = 'success' THEN 1 ELSE 0 END,
            failed_calls = failed_calls + CASE WHEN ? = 'failure' THEN 1 ELSE 0 END,
            timeout_calls = timeout_calls + CASE WHEN ? = 'timeout' THEN 1 ELSE 0 END,
            avg_response_time_ms = (avg_response_time_ms * total_calls + ?) / (total_calls + 1),
            success_rate = (successful_calls + CASE WHEN ? = 'success' THEN 1 ELSE 0 END) * 1.0 / (total_calls + 1),
            reputation_score = calculate_reputation_score(
                successful_calls + CASE WHEN ? = 'success' THEN 1 ELSE 0 END,
                total_calls + 1,
                avg_response_time_ms
            ),
            last_call_at = ?,
            updated_at = ?
        WHERE agent_identity = ?
    ">>,

    CallResultBin = atom_to_binary(CallResult),
    Now = erlang:system_time(second),

    esqlite3:exec(DB, SQL, [
        CallResultBin,
        CallResultBin,
        CallResultBin,
        ResponseTime,
        CallResultBin,
        CallResultBin,
        Event#rpc_call_tracked_v1.tracked_at,
        Now,
        Event#rpc_call_tracked_v1.provider_identity
    ]).

insert_initial_reputation(AgentIdentity, DB) ->
    SQL = <<"
        INSERT INTO agent_reputation
            (agent_identity, total_calls, successful_calls, failed_calls, timeout_calls,
             disputed_calls, avg_response_time_ms, success_rate, reputation_score, updated_at)
        VALUES (?, 0, 0, 0, 0, 0, 0.0, 0.0, 0.0, ?)
    ">>,

    esqlite3:exec(DB, SQL, [AgentIdentity, erlang:system_time(second)]).
```

**Reputation Score Algorithm:**

```sql
-- SQLite function to calculate reputation score (0-100)
CREATE FUNCTION IF NOT EXISTS calculate_reputation_score(
    successful_calls INTEGER,
    total_calls INTEGER,
    avg_response_time_ms REAL
) RETURNS REAL AS $$
BEGIN
    -- Base score from success rate (0-70 points)
    DECLARE success_score REAL := (successful_calls * 1.0 / NULLIF(total_calls, 0)) * 70;

    -- Performance score from response time (0-20 points)
    -- Fast responses (<100ms) = 20 points
    -- Slow responses (>5000ms) = 0 points
    DECLARE performance_score REAL := CASE
        WHEN avg_response_time_ms < 100 THEN 20
        WHEN avg_response_time_ms > 5000 THEN 0
        ELSE 20 - ((avg_response_time_ms - 100) / 4900 * 20)
    END;

    -- Volume bonus (0-10 points)
    -- More calls = higher confidence in score
    DECLARE volume_bonus REAL := CASE
        WHEN total_calls < 10 THEN 0
        WHEN total_calls < 50 THEN 2
        WHEN total_calls < 100 THEN 5
        WHEN total_calls < 500 THEN 7
        ELSE 10
    END;

    RETURN success_score + performance_score + volume_bonus;
END;
$$;
```

---

## Mesh Integration

### Event Publishing

**Topic:** `"rpc.call_tracked"`

**Subscribers:**
- All hecate instances (for local reputation projection)
- macula-realm (for analytics dashboard - optional)

**Flow:**
1. Agent A calls Agent B's RPC procedure
2. Both Agent A and Agent B can track the call result
3. Each publishes `rpc_call_tracked_v1` event to mesh
4. Events signed with respective UCAN keys
5. Subscribers verify signatures
6. If both parties report **same result** → project normally
7. If both parties report **different results** → mark as disputed, exclude from reputation

---

## REST API

### Endpoint

`POST /rpc/track_call`

**Request:**
```json
{
  "call_id": "01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f",
  "caller_identity": "mri:agent:io.macula.bob/gpt-assistant",
  "provider_identity": "mri:agent:io.macula.alice/claude-assistant",
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
  "procedure_name": "io.macula.alice.get_weather",
  "call_result": "success",
  "response_time_ms": 250,
  "metadata": {
    "request_id": "req-12345",
    "location": "Paris, France"
  },
  "tracked_by": "eyJhbGc...UCAN_TOKEN"
}
```

**Response (Success):**
```json
{
  "ok": true,
  "call_id": "01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f",
  "tracked_at": 1738339200,
  "published_to_mesh": true
}
```

**Response (Error - Not a Party):**
```json
{
  "ok": false,
  "error": "tracked_by_must_be_caller_or_provider",
  "details": "UCAN identity does not match caller or provider"
}
```

**Response (Error - Duplicate/Dispute):**
```json
{
  "ok": false,
  "error": "duplicate_tracking",
  "existing_result": "success",
  "new_result": "failure",
  "disputed": true
}
```

### Get Agent Reputation

`GET /reputation/{agent_mri}`

**Response:**
```json
{
  "ok": true,
  "agent_identity": "mri:agent:io.macula.alice/claude-assistant",
  "reputation": {
    "score": 87.5,
    "total_calls": 1250,
    "successful_calls": 1180,
    "failed_calls": 50,
    "timeout_calls": 20,
    "disputed_calls": 5,
    "success_rate": 0.944,
    "avg_response_time_ms": 185.3,
    "last_call_at": 1738339200,
    "updated_at": 1738339200
  }
}
```

---

## Testing

### Unit Tests

```erlang
-module(track_rpc_call_tests).
-include_lib("eunit/include/eunit.hrl").

validate_uuid_v7_test() ->
    Valid = <<"01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f">>,
    Invalid = <<"not-a-uuid">>,

    ?assertEqual(ok, maybe_track_rpc_call:validate_uuid_v7(Valid)),
    ?assertMatch({error, _}, maybe_track_rpc_call:validate_uuid_v7(Invalid)).

validate_call_result_test() ->
    ?assertEqual(ok, maybe_track_rpc_call:validate_call_result(success)),
    ?assertEqual(ok, maybe_track_rpc_call:validate_call_result(failure)),
    ?assertEqual(ok, maybe_track_rpc_call:validate_call_result(timeout)),
    ?assertMatch({error, _}, maybe_track_rpc_call:validate_call_result(invalid)).

reputation_score_calculation_test() ->
    % Perfect agent: 100% success, fast responses, high volume
    Score1 = calculate_reputation_score(1000, 1000, 80.0),
    ?assert(Score1 > 95.0),

    % Average agent: 80% success, moderate speed
    Score2 = calculate_reputation_score(80, 100, 500.0),
    ?assert(Score2 > 60.0),
    ?assert(Score2 < 80.0),

    % Poor agent: 50% success, slow
    Score3 = calculate_reputation_score(50, 100, 4000.0),
    ?assert(Score3 < 50.0).
```

### Integration Tests

```erlang
% Test: Dispute detection
dispute_detection_test(Config) ->
    % Agent A tracks successful call
    CallId = <<"01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f">>,
    track_call(alice, CallId, success),

    % Agent B tracks same call as failed - DISPUTE!
    track_call(bob, CallId, failure),

    % Verify call is marked as disputed
    {ok, [Row]} = hecate_store:query(
        <<"SELECT disputed FROM rpc_call_events WHERE call_id = ?">>,
        [CallId]
    ),

    ?assertEqual(true, maps:get(<<"disputed">>, Row)),
    ok.

% Test: Reputation updates
reputation_update_test(Config) ->
    ProviderIdentity = <<"mri:agent:io.macula.alice/claude">>,

    % Track 10 successful calls
    [track_successful_call(ProviderIdentity) || _ <- lists:seq(1, 10)],

    % Track 2 failed calls
    [track_failed_call(ProviderIdentity) || _ <- lists:seq(1, 2)],

    % Get reputation
    {ok, [Rep]} = hecate_store:query(
        <<"SELECT * FROM agent_reputation WHERE agent_identity = ?">>,
        [ProviderIdentity]
    ),

    ?assertEqual(12, maps:get(<<"total_calls">>, Rep)),
    ?assertEqual(10, maps:get(<<"successful_calls">>, Rep)),
    ?assertEqual(2, maps:get(<<"failed_calls">>, Rep)),

    SuccessRate = maps:get(<<"success_rate">>, Rep),
    ?assert(SuccessRate > 0.8),  % 10/12 = 0.833
    ok.
```

---

## Success Criteria

- [ ] Command module implemented (`track_rpc_call_v1.erl`)
- [ ] Handler validates caller/provider identity from UCAN
- [ ] Event defined (`rpc_call_tracked_v1.erl`)
- [ ] Projection to `rpc_call_events` table working
- [ ] Projection to `agent_reputation` table working
- [ ] Reputation score algorithm implemented (success_rate + performance + volume)
- [ ] Dispute detection working (conflicting reports marked)
- [ ] REST API endpoint working (`POST /rpc/track_call`)
- [ ] REST API endpoint for reputation queries (`GET /reputation/{mri}`)
- [ ] Mesh event publishing working
- [ ] Unit tests passing (>80% coverage)
- [ ] Integration tests passing (dispute detection verified)
- [ ] Documentation updated

---

## Open Questions

1. **Both parties track:** Should we require BOTH parties to track for it to count, or is one sufficient?
   - **Answer:** One is sufficient - but disputed calls excluded from reputation

2. **Dispute resolution:** How to resolve disputes (conflicting reports)?
   - **Phase 1:** Mark as disputed, exclude from reputation
   - **Phase 4:** Community voting mechanism (stake-based)
   - **Phase 6:** Automated dispute resolution (analyze call patterns)

3. **Reputation decay:** Should reputation scores decay over time if agent inactive?
   - **Answer:** Yes - Phase 3 (see PLAN_AGENTIC_SOCIAL_NETWORK.md, Open Question #4)

4. **Anonymous tracking:** Should we allow tracking without revealing caller identity?
   - **Answer:** No - transparency is key to trust

5. **Retroactive tracking:** Can agents track calls that happened in the past?
   - **Answer:** Yes, but with timestamp limits (max 24 hours old)

---

## Related Plans

- [PLAN_ANNOUNCE_CAPABILITY.md](PLAN_ANNOUNCE_CAPABILITY.md) - Capability tracking references
- [PLAN_DISCOVER_CAPABILITIES.md](PLAN_DISCOVER_CAPABILITIES.md) - Uses reputation for ranking
- [PLAN_CALCULATE_REPUTATION.md](PLAN_CALCULATE_REPUTATION.md) - Advanced reputation algorithms
- [PLAN_AGENTIC_SOCIAL_NETWORK.md](PLAN_AGENTIC_SOCIAL_NETWORK.md) - Overall architecture
