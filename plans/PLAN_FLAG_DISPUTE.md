# PLAN: flag_dispute

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** PLAN_TRACK_RPC_CALL.md
**Domain:** Reputation (Command Service)

---

## Business Goal

Enable agents to **flag conflicting RPC call reports** when:
- Caller and provider report different results for the same call
- One party reports success, other reports failure
- Response times differ significantly
- Call wasn't actually made (false claim)

This creates transparency and accountability in the reputation system.

**Use Case:** Alice calls Bob's weather service. Alice tracks it as "timeout" but Bob tracks it as "success in 200ms". This is suspicious - one of them is lying or their clocks are wrong. The system should flag this for investigation.

---

## Event Storm

### Command

**Name:** `flag_dispute_v1`
**Module:** `src/flag_dispute/flag_dispute_v1.erl`

**Structure:**
```erlang
-record(flag_dispute_v1, {
    call_id :: binary(),               % UUID v7 of the disputed RPC call
    disputing_party :: binary(),       % MRI of agent flagging the dispute
    reason :: atom(),                  % See reasons below
    evidence :: map(),                 % Supporting data
    flagged_by :: binary()             % UCAN token
}).
```

**Dispute Reasons:**
```erlang
-define(CONFLICTING_RESULTS, conflicting_results).  % Caller and provider report different outcomes
-define(TIMING_MISMATCH, timing_mismatch).          % Response times differ > 500ms
-define(FALSE_CLAIM, false_claim).                  % Call never happened
-define(DUPLICATE_TRACKING, duplicate_tracking).    % Same call tracked twice
```

**Evidence Map:**
```erlang
#{
    <<"caller_report">> => map(),      % Caller's tracking event
    <<"provider_report">> => map(),    % Provider's tracking event
    <<"notes">> => binary()            % Human-readable explanation
}
```

**Validation Rules:**
1. `call_id` MUST exist (at least one party tracked it)
2. `disputing_party` MUST be either caller OR provider (third parties can't dispute)
3. `reason` MUST be valid dispute reason
4. `flagged_by` MUST be valid UCAN token
5. Cannot dispute the same call twice

**Example:**
```erlang
Command = #flag_dispute_v1{
    call_id = <<"01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f">>,
    disputing_party = <<"mri:agent:io.macula.alice/weather-bot">>,
    reason = conflicting_results,
    evidence = #{
        <<"caller_report">> => #{
            <<"call_result">> => <<"timeout">>,
            <<"response_time_ms">> => 5000
        },
        <<"provider_report">> => #{
            <<"call_result">> => <<"success">>,
            <<"response_time_ms">> => 234
        },
        <<"notes">> => <<"I never received a response, but provider claims success">>
    },
    flagged_by = <<"eyJhbGc...UCAN_TOKEN">>
}.
```

---

### Event

**Name:** `dispute_flagged_v1`
**Module:** `src/flag_dispute/dispute_flagged_v1.erl`

**Structure:**
```erlang
-record(dispute_flagged_v1, {
    dispute_id :: binary(),            % UUID v7 for this dispute
    call_id :: binary(),
    disputing_party :: binary(),
    reason :: atom(),
    evidence :: map(),
    status :: atom(),                  % pending
    flagged_at :: integer()
}).
```

---

### Handler

**Name:** `maybe_flag_dispute`
**Module:** `src/flag_dispute/maybe_flag_dispute.erl`

**Logic:**
1. Validate call_id exists
2. Validate disputing_party is involved in the call
3. Check for duplicate dispute on same call
4. Validate UCAN token
5. Create dispute event with status = pending

**Pseudocode:**
```erlang
-module(maybe_flag_dispute).
-export([handle/1]).

handle(#flag_dispute_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_call_exists(Cmd#flag_dispute_v1.call_id) end,
        fun() -> validate_party_involved(Cmd) end,
        fun() -> validate_no_duplicate_dispute(Cmd#flag_dispute_v1.call_id) end,
        fun() -> validate_ucan(Cmd#flag_dispute_v1.flagged_by, Cmd#flag_dispute_v1.disputing_party) end
    ], fun() ->
        {ok, create_event(Cmd)}
    end).

validate_call_exists(CallId) ->
    case query_reputation:get_rpc_call(CallId) of
        {ok, _Call} -> ok;
        {error, not_found} -> {error, <<"RPC call not found">>}
    end.

validate_party_involved(#flag_dispute_v1{call_id = CallId, disputing_party = Party}) ->
    case query_reputation:get_rpc_call(CallId) of
        {ok, #{caller_identity := Party}} -> ok;
        {ok, #{provider_identity := Party}} -> ok;
        {ok, _} -> {error, <<"Only caller or provider can dispute this call">>}
    end.

validate_no_duplicate_dispute(CallId) ->
    case query_reputation:get_dispute_by_call(CallId) of
        {ok, _Dispute} -> {error, <<"This call already has a dispute">>};
        {error, not_found} -> ok
    end.

create_event(#flag_dispute_v1{} = Cmd) ->
    #dispute_flagged_v1{
        dispute_id = uuid:v7(),
        call_id = Cmd#flag_dispute_v1.call_id,
        disputing_party = Cmd#flag_dispute_v1.disputing_party,
        reason = Cmd#flag_dispute_v1.reason,
        evidence = Cmd#flag_dispute_v1.evidence,
        status = pending,
        flagged_at = erlang:system_time(millisecond)
    }.
```

---

### Projection

**Name:** `dispute_flagged_v1_to_disputes`
**Module:** `src/../query_reputation/dispute_flagged_v1_to_disputes.erl`

**Logic:**
Insert into `disputes` table.

**Schema:**
```sql
CREATE TABLE disputes (
    dispute_id TEXT PRIMARY KEY,
    call_id TEXT NOT NULL,
    disputing_party TEXT NOT NULL,
    reason TEXT NOT NULL,
    evidence TEXT,          -- JSON
    status TEXT NOT NULL,   -- pending | resolved | dismissed
    flagged_at INTEGER NOT NULL,
    resolved_at INTEGER,
    resolution TEXT,        -- JSON (who was right, evidence)
    FOREIGN KEY (call_id) REFERENCES rpc_calls(call_id)
);
```

---

## Mesh Integration

### Topic

**Publish to:** `reputation.dispute_flagged`

**Subscribers:**
- All query_reputation services
- macula-realm (show dispute in UI)
- Involved agents (notify caller and provider)

---

## REST API

### Endpoint

```
POST /disputes
Content-Type: application/json
Authorization: Bearer <ucan-token>

{
  "call_id": "01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f",
  "reason": "conflicting_results",
  "evidence": {
    "caller_report": {...},
    "provider_report": {...},
    "notes": "I never received a response, but provider claims success"
  }
}

Response 201:
{
  "ok": true,
  "dispute_id": "01935d2b-...",
  "status": "pending",
  "flagged_at": "2026-01-31T12:00:00Z"
}
```

---

## Impact on Reputation

**While dispute is pending:**
- Both parties' reputation scores are **NOT affected**
- Disputed call is **marked as disputed** in UI
- Disputed call is **NOT counted** in reputation calculation

**After resolution:**
- If caller was right: Provider's reputation decreases
- If provider was right: Caller's reputation decreases (for false dispute)
- If inconclusive: No reputation change

---

## Success Criteria

- [ ] Only involved parties can flag disputes
- [ ] No duplicate disputes on same call
- [ ] Event published to mesh
- [ ] Projection creates dispute record
- [ ] REST API works
- [ ] Disputed calls excluded from reputation calculation
- [ ] Both parties notified

---

**Related Plans:**
- [PLAN_TRACK_RPC_CALL.md](PLAN_TRACK_RPC_CALL.md)
- [PLAN_RESOLVE_DISPUTE.md](PLAN_RESOLVE_DISPUTE.md)
- [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
