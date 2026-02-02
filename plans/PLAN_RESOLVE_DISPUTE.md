# PLAN: resolve_dispute

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** PLAN_FLAG_DISPUTE.md
**Domain:** Reputation (Command Service)

---

## Business Goal

Enable **dispute resolution** through:
- Automated verification (compare timestamps, check logs)
- Community moderation (trusted agents vote)
- Manual review (realm admins)

This ensures the reputation system remains trustworthy.

---

## Event Storm

### Command

**Name:** `resolve_dispute_v1`
**Module:** `src/resolve_dispute/resolve_dispute_v1.erl`

**Structure:**
```erlang
-record(resolve_dispute_v1, {
    dispute_id :: binary(),            % UUID v7 of dispute to resolve
    resolution :: atom(),              % See resolutions below
    evidence :: map(),                 % Supporting data
    resolved_by :: binary()            % UCAN token (moderator or system)
}).
```

**Resolutions:**
```erlang
-define(CALLER_CORRECT, caller_correct).        % Caller's report was accurate
-define(PROVIDER_CORRECT, provider_correct).    % Provider's report was accurate
-define(BOTH_CORRECT, both_correct).            % Clock skew, but both honest
-define(INCONCLUSIVE, inconclusive).            % Can't determine
-define(DISMISSED, dismissed).                  % False/spam dispute
```

**Evidence Map:**
```erlang
#{
    <<"reason">> => binary(),              % Human-readable explanation
    <<"proof">> => binary(),               % URLs to logs, screenshots, etc.
    <<"verified_by">> => [binary()]        % MRIs of verifying moderators
}
```

**Validation Rules:**
1. `dispute_id` MUST exist and be in `pending` status
2. `resolved_by` MUST have moderator privileges (UCAN capability)
3. `resolution` MUST be valid
4. `evidence` MUST contain reason

**Example:**
```erlang
Command = #resolve_dispute_v1{
    dispute_id = <<"01935d2b-...">>,
    resolution = caller_correct,
    evidence = #{
        <<"reason">> => <<"Server logs show provider never sent a response within timeout window">>,
        <<"proof">> => <<"https://logs.macula.io/...">>,
        <<"verified_by">> => [
            <<"mri:agent:io.macula.moderator/alice">>,
            <<"mri:agent:io.macula.moderator/bob">>
        ]
    },
    resolved_by = <<"eyJhbGc...MODERATOR_UCAN_TOKEN">>
}.
```

---

### Event

**Name:** `dispute_resolved_v1`
**Module:** `src/resolve_dispute/dispute_resolved_v1.erl`

**Structure:**
```erlang
-record(dispute_resolved_v1, {
    dispute_id :: binary(),
    call_id :: binary(),               % For easier querying
    resolution :: atom(),
    evidence :: map(),
    resolved_at :: integer()
}).
```

---

### Handler

**Name:** `maybe_resolve_dispute`
**Module:** `src/resolve_dispute/maybe_resolve_dispute.erl`

**Logic:**
1. Validate dispute exists and is pending
2. Validate resolver has moderator privileges
3. Create resolution event
4. Trigger reputation adjustments based on resolution

**Pseudocode:**
```erlang
-module(maybe_resolve_dispute).
-export([handle/1]).

handle(#resolve_dispute_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_dispute_exists(Cmd#resolve_dispute_v1.dispute_id) end,
        fun() -> validate_dispute_pending(Cmd#resolve_dispute_v1.dispute_id) end,
        fun() -> validate_moderator_privileges(Cmd#resolve_dispute_v1.resolved_by) end
    ], fun() ->
        {ok, create_event(Cmd)}
    end).

validate_dispute_exists(DisputeId) ->
    case query_reputation:get_dispute(DisputeId) of
        {ok, _Dispute} -> ok;
        {error, not_found} -> {error, <<"Dispute not found">>}
    end.

validate_dispute_pending(DisputeId) ->
    case query_reputation:get_dispute(DisputeId) of
        {ok, #{status := pending}} -> ok;
        {ok, #{status := _Other}} -> {error, <<"Dispute already resolved">>}
    end.

validate_moderator_privileges(UcanToken) ->
    %% Check UCAN token has "moderate_disputes" capability
    case ucan:verify(UcanToken, <<"moderate_disputes">>) of
        {ok, _Claims} -> ok;
        {error, _} -> {error, <<"Insufficient privileges to resolve disputes">>}
    end.

create_event(#resolve_dispute_v1{} = Cmd) ->
    {ok, Dispute} = query_reputation:get_dispute(Cmd#resolve_dispute_v1.dispute_id),

    #dispute_resolved_v1{
        dispute_id = Cmd#resolve_dispute_v1.dispute_id,
        call_id = maps:get(call_id, Dispute),
        resolution = Cmd#resolve_dispute_v1.resolution,
        evidence = Cmd#resolve_dispute_v1.evidence,
        resolved_at = erlang:system_time(millisecond)
    }.
```

---

### Projection

**Name:** `dispute_resolved_v1_to_disputes`
**Module:** `src/../query_reputation/dispute_resolved_v1_to_disputes.erl`

**Logic:**
Update dispute status to resolved.

**Pseudocode:**
```erlang
-module(dispute_resolved_v1_to_disputes).
-export([project/1]).

project(Event) ->
    #{
        <<"dispute_id">> := DisputeId,
        <<"resolution">> := Resolution,
        <<"evidence">> := Evidence,
        <<"resolved_at">> := Time
    } = Event,

    SQL = <<"
        UPDATE disputes
        SET status = 'resolved',
            resolution = ?,
            resolved_at = ?
        WHERE dispute_id = ?
    ">>,

    EvidenceJson = jsx:encode(Evidence),
    hecate_store:execute(SQL, [atom_to_binary(Resolution), Time, DisputeId]),

    %% Trigger reputation recalculation
    trigger_reputation_update(Event).

trigger_reputation_update(#{<<"call_id">> := CallId, <<"resolution">> := Resolution}) ->
    {ok, Call} = query_reputation:get_rpc_call(CallId),
    CallerMri = maps:get(caller_identity, Call),
    ProviderMri = maps:get(provider_identity, Call),

    case Resolution of
        caller_correct ->
            %% Provider's reputation should decrease
            decrease_reputation(ProviderMri, <<"false_success_claim">>);
        provider_correct ->
            %% Caller filed false dispute, decrease their reputation
            decrease_reputation(CallerMri, <<"false_dispute">>);
        both_correct ->
            %% No reputation change, just clock skew
            ok;
        inconclusive ->
            %% No reputation change
            ok;
        dismissed ->
            %% Decrease disputing party's reputation
            {ok, Dispute} = query_reputation:get_dispute(DisputeId),
            decrease_reputation(maps:get(disputing_party, Dispute), <<"spam_dispute">>)
    end.

decrease_reputation(AgentMri, Reason) ->
    %% Implementation: Adjust reputation score
    %% This might trigger another event: reputation_adjusted_v1
    ok.
```

---

## Mesh Integration

### Topic

**Publish to:** `reputation.dispute_resolved`

**Subscribers:**
- All query_reputation services
- macula-realm (update UI)
- Involved agents (notify outcome)

---

## REST API

### Endpoint

```
POST /disputes/:dispute_id/resolve
Content-Type: application/json
Authorization: Bearer <moderator-ucan-token>

{
  "resolution": "caller_correct",
  "evidence": {
    "reason": "Server logs show provider never sent a response...",
    "proof": "https://logs.macula.io/...",
    "verified_by": ["mri:agent:io.macula.moderator/alice"]
  }
}

Response 200:
{
  "ok": true,
  "dispute_id": "01935d2b-...",
  "resolution": "caller_correct",
  "resolved_at": "2026-01-31T12:00:00Z"
}

Response 403:
{
  "ok": false,
  "error": "unauthorized",
  "message": "Insufficient privileges to resolve disputes"
}

Response 409:
{
  "ok": false,
  "error": "already_resolved"
}
```

---

## Moderator Privileges

**Who can resolve disputes:**
1. **Realm admins** - Can resolve any dispute in their realm
2. **Trusted moderators** - Community-elected agents with proven track record
3. **Automated system** - For clear-cut cases (e.g., timestamps prove one party wrong)

**UCAN Capability:**
```json
{
  "aud": "mri:agent:io.macula.moderator/alice",
  "att": [{
    "with": "mri:realm:io.macula",
    "can": "moderate_disputes"
  }]
}
```

---

## Success Criteria

- [ ] Only moderators can resolve
- [ ] Resolution updates dispute status
- [ ] Reputation adjusted based on resolution
- [ ] Event published to mesh
- [ ] Both parties notified
- [ ] Disputed call becomes countable in reputation after resolution
- [ ] REST API works
- [ ] UI shows resolution details

---

**Related Plans:**
- [PLAN_FLAG_DISPUTE.md](PLAN_FLAG_DISPUTE.md)
- [PLAN_TRACK_RPC_CALL.md](PLAN_TRACK_RPC_CALL.md)
- [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
