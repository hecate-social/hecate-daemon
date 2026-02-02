# PLAN: announce_capability

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** None (foundational process)

---

## Business Goal

Enable agents to **declare new capabilities to the mesh network**, making them discoverable by other agents. When an agent announces a capability, the announcement is:
- Stored locally in the agent's ReckonDB
- Published to the mesh via DHT pub/sub
- Signed with the agent's UCAN key for verification
- Projected into local read models by all subscribing hecate instances

This is the **foundation of the agentic social network** - without capability announcements, there is no discovery.

---

## Event Storm

### Command

**Name:** `announce_capability_v1`
**Module:** `src/announce_capability/announce_capability_v1.erl`

**Structure:**
```erlang
-record(announce_capability_v1, {
    capability_mri :: binary(),        % "mri:capability:io.macula.alice/weather-forecast"
    agent_identity :: binary(),        % "mri:agent:io.macula.alice/claude-assistant"
    tags :: [binary()],               % ["weather", "forecast", "api"]
    description :: binary(),          % "Provides weather forecasts for any location"
    demo_procedure :: binary(),       % "io.macula.alice.demo_weather" (RPC to demo this capability)
    metadata :: map(),                % Optional: version, license, homepage, etc.
    announced_by :: binary()          % UCAN token of announcing agent
}).
```

**Validation Rules:**
1. `capability_mri` MUST be valid MRI format: `mri:capability:{realm}/{name}`
2. `agent_identity` MUST be valid MRI format: `mri:agent:{realm}/{name}`
3. `agent_identity` realm MUST match `capability_mri` realm (agents own their capabilities)
4. `tags` MUST be non-empty list (minimum 1 tag)
5. `description` MUST be 10-1000 characters
6. `demo_procedure` MUST be valid RPC procedure name (registered or will be registered)
7. `announced_by` MUST be valid UCAN token
8. UCAN token MUST grant capability to announce for this agent identity

**Example:**
```erlang
Command = #announce_capability_v1{
    capability_mri = <<"mri:capability:io.macula.alice/weather-forecast">>,
    agent_identity = <<"mri:agent:io.macula.alice/claude-assistant">>,
    tags = [<<"weather">>, <<"forecast">>, <<"api">>],
    description = <<"Provides weather forecasts for any location using OpenWeather API">>,
    demo_procedure = <<"io.macula.alice.demo_weather">>,
    metadata = #{
        <<"version">> => <<"1.0.0">>,
        <<"license">> => <<"MIT">>,
        <<"homepage">> => <<"https://github.com/alice/weather-agent">>
    },
    announced_by = <<"eyJhbGc...UCAN_TOKEN">>
}.
```

---

### Handler

**Name:** `maybe_announce_capability`
**Module:** `src/announce_capability/maybe_announce_capability.erl`

**Logic:**
1. Validate command structure (all required fields present)
2. Validate MRI formats (capability and agent)
3. Validate realm ownership (agent owns capability)
4. Validate UCAN token (signature, expiry, capability grant)
5. Check for duplicate announcement (same capability_mri already announced)
6. If all valid, create event
7. If invalid, return error with reason

**Pseudocode:**
```erlang
-module(maybe_announce_capability).
-export([handle/1]).

handle(#announce_capability_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_mri_format(Cmd#announce_capability_v1.capability_mri) end,
        fun() -> validate_mri_format(Cmd#announce_capability_v1.agent_identity) end,
        fun() -> validate_realm_ownership(Cmd) end,
        fun() -> validate_tags(Cmd#announce_capability_v1.tags) end,
        fun() -> validate_description(Cmd#announce_capability_v1.description) end,
        fun() -> validate_ucan(Cmd#announce_capability_v1.announced_by, Cmd#announce_capability_v1.agent_identity) end,
        fun() -> check_not_duplicate(Cmd#announce_capability_v1.capability_mri) end
    ], fun() ->
        {ok, create_event(Cmd)}
    end).

validate_mri_format(MRI) ->
    case binary:split(MRI, <<":">>, [global]) of
        [<<"mri">>, Type, RealmAndName] when Type =:= <<"capability">> orelse Type =:= <<"agent">> ->
            ok;
        _ ->
            {error, {invalid_mri, MRI}}
    end.

validate_realm_ownership(#announce_capability_v1{capability_mri = CapMRI, agent_identity = AgentMRI}) ->
    CapRealm = extract_realm(CapMRI),
    AgentRealm = extract_realm(AgentMRI),
    case CapRealm =:= AgentRealm of
        true -> ok;
        false -> {error, {realm_mismatch, CapRealm, AgentRealm}}
    end.

validate_tags(Tags) when is_list(Tags), length(Tags) > 0 ->
    ok;
validate_tags(_) ->
    {error, tags_must_be_non_empty_list}.

validate_description(Desc) when is_binary(Desc) ->
    Len = byte_size(Desc),
    if
        Len < 10 -> {error, description_too_short};
        Len > 1000 -> {error, description_too_long};
        true -> ok
    end.

validate_ucan(Token, AgentIdentity) ->
    case hecate_ucan:verify(Token) of
        {ok, Claims} ->
            % Check token grants capability to announce for this agent
            case lists:member({<<"announce_capability">>, AgentIdentity}, Claims) of
                true -> ok;
                false -> {error, ucan_missing_capability}
            end;
        {error, Reason} ->
            {error, {ucan_invalid, Reason}}
    end.

check_not_duplicate(CapabilityMRI) ->
    % Query local projection to see if already announced
    case hecate_store:exists(<<"capabilities">>, CapabilityMRI) of
        false -> ok;
        true -> {error, {already_announced, CapabilityMRI}}
    end.

create_event(#announce_capability_v1{} = Cmd) ->
    #capability_announced_v1{
        capability_mri = Cmd#announce_capability_v1.capability_mri,
        agent_identity = Cmd#announce_capability_v1.agent_identity,
        tags = Cmd#announce_capability_v1.tags,
        description = Cmd#announce_capability_v1.description,
        demo_procedure = Cmd#announce_capability_v1.demo_procedure,
        metadata = Cmd#announce_capability_v1.metadata,
        announced_at = erlang:system_time(second)
    }.

with_validations([], Success) ->
    Success();
with_validations([Validation | Rest], Success) ->
    case Validation() of
        ok -> with_validations(Rest, Success);
        {error, _} = Error -> Error
    end.
```

---

### Event

**Name:** `capability_announced_v1`
**Module:** `src/announce_capability/capability_announced_v1.erl`

**Structure:**
```erlang
-record(capability_announced_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()],
    description :: binary(),
    demo_procedure :: binary(),
    metadata :: map(),
    announced_at :: integer()  % Unix timestamp (seconds)
}).
```

**Mesh Topic:** `"capability.announced"`

**Event Signing:**
```erlang
% Agent signs the event before publishing
EventBytes = term_to_binary(Event),
{ok, Signature} = hecate_identity:sign(EventBytes),
{ok, DID} = hecate_identity:get_did(),

PublishedEvent = #{
    <<"event">> => Event,
    <<"signature">> => Signature,
    <<"agent_did">> => DID,
    <<"event_type">> => <<"capability_announced_v1">>
}.

% Publish to mesh
hecate_mesh:publish("capability.announced", PublishedEvent).
```

**Event Verification (by subscribers):**
```erlang
% Subscribers verify event signature before projecting
handle_mesh_event(#{
    <<"event">> := Event,
    <<"signature">> := Sig,
    <<"agent_did">> := DID
} = Payload) ->
    EventBytes = term_to_binary(Event),
    case hecate_ucan:verify_signature(EventBytes, Sig, DID) of
        {ok, true} ->
            % Event is authentic, project it
            project_event(Event);
        {ok, false} ->
            lager:warning("Invalid signature from ~s", [DID]),
            ignore;
        {error, Reason} ->
            lager:error("Signature verification failed: ~p", [Reason]),
            ignore
    end.
```

---

### Projection

**Name:** `capability_announced_v1_to_capabilities`
**Module:** `src/announce_capability/capability_announced_v1_to_capabilities.erl`

**Target Table:** `capabilities`

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS capabilities (
    capability_mri TEXT PRIMARY KEY,
    agent_identity TEXT NOT NULL,
    tags TEXT NOT NULL,              -- JSON array: ["weather", "forecast"]
    description TEXT NOT NULL,
    demo_procedure TEXT NOT NULL,
    metadata TEXT,                   -- JSON object: {"version": "1.0.0", ...}
    announced_at INTEGER NOT NULL,

    -- Indexes for fast queries
    INDEX idx_agent_identity ON capabilities(agent_identity),
    INDEX idx_announced_at ON capabilities(announced_at DESC)
);

-- Full-text search index on tags and description
CREATE VIRTUAL TABLE IF NOT EXISTS capabilities_fts USING fts5(
    capability_mri,
    tags,
    description,
    content='capabilities'
);
```

**Projection Logic:**
```erlang
-module(capability_announced_v1_to_capabilities).
-export([project/2]).

project(#capability_announced_v1{} = Event, DB) ->
    TagsJson = jsx:encode(Event#capability_announced_v1.tags),
    MetadataJson = jsx:encode(Event#capability_announced_v1.metadata),

    % Insert into main table
    SQL = <<"
        INSERT OR REPLACE INTO capabilities
            (capability_mri, agent_identity, tags, description, demo_procedure, metadata, announced_at)
        VALUES (?, ?, ?, ?, ?, ?, ?)
    ">>,

    case esqlite3:exec(DB, SQL, [
        Event#capability_announced_v1.capability_mri,
        Event#capability_announced_v1.agent_identity,
        TagsJson,
        Event#capability_announced_v1.description,
        Event#capability_announced_v1.demo_procedure,
        MetadataJson,
        Event#capability_announced_v1.announced_at
    ]) of
        ok ->
            % Update FTS index
            update_fts_index(DB, Event),
            ok;
        {error, Reason} ->
            lager:error("Failed to project capability_announced_v1: ~p", [Reason]),
            {error, Reason}
    end.

update_fts_index(DB, #capability_announced_v1{} = Event) ->
    % FTS index for full-text search on tags and description
    FTSSQL = <<"
        INSERT OR REPLACE INTO capabilities_fts
            (capability_mri, tags, description)
        VALUES (?, ?, ?)
    ">>,

    TagsText = binary:list_to_bin(lists:join(<<" ">>, Event#capability_announced_v1.tags)),

    esqlite3:exec(DB, FTSSQL, [
        Event#capability_announced_v1.capability_mri,
        TagsText,
        Event#capability_announced_v1.description
    ]).
```

---

## Mesh Integration

### Event Publishing

**Topic:** `"capability.announced"`

**Subscribers:**
- All hecate instances in the mesh (for local projection)
- macula-realm (for web UI visualization - optional)

**Flow:**
1. Local agent calls `POST /capabilities/announce` on hecate REST API
2. hecate processes command, creates event
3. Event stored in local ReckonDB (source of truth)
4. Event signed with agent's private key
5. Signed event published to mesh topic `"capability.announced"`
6. Other hecate instances subscribe to topic
7. Subscribers verify signature
8. Valid events projected into local SQLite `capabilities` table

### Local Storage

**ReckonDB (Event Store):**
- Stream: `capability-{capability_mri}`
- Event: `capability_announced_v1`
- Position: Auto-incrementing

**SQLite (Read Model):**
- Table: `capabilities`
- FTS Table: `capabilities_fts` (for search)

### Discovery

**Local Query (Fast):**
```erlang
% Query local projection
hecate_store:query(<<"
    SELECT * FROM capabilities
    WHERE agent_identity = ?
    ORDER BY announced_at DESC
">>, [AgentIdentity]).
```

**Mesh Query (Slower, but complete):**
```erlang
% If not found locally, query mesh DHT
hecate_mesh:call(Peer, "dht.query.capabilities", #{
    <<"agent_identity">> => AgentIdentity
}).
```

---

## REST API

### Endpoint

`POST /capabilities/announce`

**Request:**
```json
{
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
  "agent_identity": "mri:agent:io.macula.alice/claude-assistant",
  "tags": ["weather", "forecast", "api"],
  "description": "Provides weather forecasts for any location using OpenWeather API",
  "demo_procedure": "io.macula.alice.demo_weather",
  "metadata": {
    "version": "1.0.0",
    "license": "MIT",
    "homepage": "https://github.com/alice/weather-agent"
  },
  "announced_by": "eyJhbGc...UCAN_TOKEN"
}
```

**Response (Success):**
```json
{
  "ok": true,
  "event_id": "01935d2a-3f7e-7b8c-9d4e-5a6f7c8d9e0f",
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
  "published_to_mesh": true,
  "announced_at": 1738339200
}
```

**Response (Error - Validation Failed):**
```json
{
  "ok": false,
  "error": "realm_mismatch",
  "details": {
    "capability_realm": "io.macula.alice",
    "agent_realm": "io.macula.bob"
  }
}
```

**Response (Error - Already Announced):**
```json
{
  "ok": false,
  "error": "already_announced",
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast"
}
```

**Response (Error - Invalid UCAN):**
```json
{
  "ok": false,
  "error": "ucan_invalid",
  "reason": "token_expired"
}
```

### API Handler

**Module:** `src/hecate_api_capabilities.erl`

```erlang
-module(hecate_api_capabilities).
-export([init/2]).

init(Req0, [announce]) ->
    handle_announce(Req0);
init(Req0, State) ->
    {ok, Req0, State}.

handle_announce(Req0) ->
    case cowboy_req:method(Req0) of
        <<"POST">> ->
            {ok, Body, Req1} = cowboy_req:read_body(Req0),
            case jsx:decode(Body, [return_maps]) of
                #{<<"capability_mri">> := _} = Payload ->
                    Command = payload_to_command(Payload),
                    case maybe_announce_capability:handle(Command) of
                        {ok, Event} ->
                            % Store in ReckonDB
                            {ok, EventId} = store_event(Event),
                            % Publish to mesh
                            ok = publish_to_mesh(Event),
                            % Return success
                            Response = #{
                                <<"ok">> => true,
                                <<"event_id">> => EventId,
                                <<"capability_mri">> => Event#capability_announced_v1.capability_mri,
                                <<"published_to_mesh">> => true,
                                <<"announced_at">> => Event#capability_announced_v1.announced_at
                            },
                            reply_json(200, Response, Req1);
                        {error, Reason} ->
                            Response = #{
                                <<"ok">> => false,
                                <<"error">> => format_error(Reason)
                            },
                            reply_json(400, Response, Req1)
                    end;
                _ ->
                    reply_json(400, #{<<"ok">> => false, <<"error">> => <<"invalid_payload">>}, Req1)
            end;
        _ ->
            reply_json(405, #{<<"ok">> => false, <<"error">> => <<"method_not_allowed">>}, Req0)
    end.
```

---

## Testing

### Unit Tests

**Module:** `test/announce_capability_tests.erl`

```erlang
-module(announce_capability_tests).
-include_lib("eunit/include/eunit.hrl").

% Command validation tests
validate_mri_format_test() ->
    Valid = <<"mri:capability:io.macula.alice/weather">>,
    Invalid = <<"not-an-mri">>,
    ?assertEqual(ok, maybe_announce_capability:validate_mri_format(Valid)),
    ?assertMatch({error, {invalid_mri, _}}, maybe_announce_capability:validate_mri_format(Invalid)).

validate_realm_ownership_test() ->
    Cmd = #announce_capability_v1{
        capability_mri = <<"mri:capability:io.macula.alice/weather">>,
        agent_identity = <<"mri:agent:io.macula.alice/claude">>
    },
    ?assertEqual(ok, maybe_announce_capability:validate_realm_ownership(Cmd)),

    BadCmd = Cmd#announce_capability_v1{
        agent_identity = <<"mri:agent:io.macula.bob/claude">>
    },
    ?assertMatch({error, {realm_mismatch, _, _}}, maybe_announce_capability:validate_realm_ownership(BadCmd)).

validate_tags_test() ->
    ?assertEqual(ok, maybe_announce_capability:validate_tags([<<"weather">>])),
    ?assertMatch({error, _}, maybe_announce_capability:validate_tags([])),
    ?assertMatch({error, _}, maybe_announce_capability:validate_tags(not_a_list)).

validate_description_test() ->
    TooShort = <<"short">>,
    TooLong = binary:copy(<<"x">>, 1001),
    JustRight = <<"This is a good description with enough detail.">>,

    ?assertMatch({error, description_too_short}, maybe_announce_capability:validate_description(TooShort)),
    ?assertMatch({error, description_too_long}, maybe_announce_capability:validate_description(TooLong)),
    ?assertEqual(ok, maybe_announce_capability:validate_description(JustRight)).

% Handler tests
handle_valid_command_test() ->
    Cmd = #announce_capability_v1{
        capability_mri = <<"mri:capability:io.macula.alice/weather">>,
        agent_identity = <<"mri:agent:io.macula.alice/claude">>,
        tags = [<<"weather">>, <<"forecast">>],
        description = <<"Weather forecasting service for global locations">>,
        demo_procedure = <<"io.macula.alice.demo_weather">>,
        metadata = #{},
        announced_by = <<"VALID_UCAN_TOKEN">>
    },

    % Mock UCAN verification
    meck:new(hecate_ucan),
    meck:expect(hecate_ucan, verify, fun(_) -> {ok, [{<<"announce_capability">>, Cmd#announce_capability_v1.agent_identity}]} end),

    % Mock duplicate check
    meck:new(hecate_store),
    meck:expect(hecate_store, exists, fun(_, _) -> false end),

    {ok, Event} = maybe_announce_capability:handle(Cmd),
    ?assertMatch(#capability_announced_v1{}, Event),
    ?assertEqual(Cmd#announce_capability_v1.capability_mri, Event#capability_announced_v1.capability_mri),

    meck:unload(hecate_ucan),
    meck:unload(hecate_store).

% Projection tests
project_event_test() ->
    Event = #capability_announced_v1{
        capability_mri = <<"mri:capability:io.macula.alice/weather">>,
        agent_identity = <<"mri:agent:io.macula.alice/claude">>,
        tags = [<<"weather">>, <<"forecast">>],
        description = <<"Weather service">>,
        demo_procedure = <<"io.macula.alice.demo_weather">>,
        metadata = #{},
        announced_at = 1738339200
    },

    % Mock SQLite
    {ok, DB} = esqlite3:open(":memory:"),
    esqlite3:exec(DB, <<"CREATE TABLE capabilities (...);">>),

    ?assertEqual(ok, capability_announced_v1_to_capabilities:project(Event, DB)),

    % Verify projection
    {ok, Rows} = esqlite3:q(DB, <<"SELECT * FROM capabilities WHERE capability_mri = ?">>,
                             [Event#capability_announced_v1.capability_mri]),
    ?assertEqual(1, length(Rows)),

    esqlite3:close(DB).
```

### Integration Tests

**Module:** `test/announce_capability_integration_tests.erl`

```erlang
-module(announce_capability_integration_tests).
-include_lib("common_test/include/ct.hrl").

% Test: Event published to mesh
event_published_to_mesh_test(Config) ->
    % Start hecate
    {ok, _} = application:ensure_all_started(hecate),

    % Subscribe to mesh topic
    hecate_mesh:subscribe("capability.announced", self()),

    % Announce capability via API
    Payload = #{
        <<"capability_mri">> => <<"mri:capability:io.macula.alice/weather">>,
        <<"agent_identity">> => <<"mri:agent:io.macula.alice/claude">>,
        <<"tags">> => [<<"weather">>],
        <<"description">> => <<"Weather forecasting service">>,
        <<"demo_procedure">> => <<"io.macula.alice.demo_weather">>,
        <<"announced_by">> => <<"VALID_UCAN_TOKEN">>
    },

    {ok, Response} = httpc:request(post,
        {"http://localhost:4444/capabilities/announce", [], "application/json", jsx:encode(Payload)},
        [], []),

    ?assertMatch({{"HTTP/1.1", 200, "OK"}, _, _}, Response),

    % Wait for mesh event
    receive
        {mesh_event, <<"capability.announced">>, Event} ->
            ?assertMatch(#{<<"event">> := _}, Event),
            ok
    after 5000 ->
        ct:fail("Did not receive mesh event")
    end.

% Test: Other instances receive and project
multi_instance_projection_test(Config) ->
    % Start two hecate instances
    {ok, _} = start_hecate_instance(node1),
    {ok, _} = start_hecate_instance(node2),

    % Node1 announces capability
    announce_on_node(node1, #{...}),

    % Wait for node2 to receive and project
    timer:sleep(1000),

    % Query node2's local projection
    {ok, Rows} = query_node(node2, <<"SELECT * FROM capabilities WHERE capability_mri = ?">>,
                             [<<"mri:capability:io.macula.alice/weather">>]),

    ?assertEqual(1, length(Rows)),
    ok.
```

### E2E Tests

**Scenario:** Local agent announces capability, remote agent discovers it

```erlang
e2e_announce_and_discover_test(Config) ->
    % Setup: Two agents with hecate gateways
    {ok, AliceHecate} = start_hecate(alice),
    {ok, BobHecate} = start_hecate(bob),

    % Alice announces weather capability
    AlicePayload = #{
        <<"capability_mri">> => <<"mri:capability:io.macula.alice/weather">>,
        <<"agent_identity">> => <<"mri:agent:io.macula.alice/claude">>,
        <<"tags">> => [<<"weather">>, <<"forecast">>],
        <<"description">> => <<"Weather forecasting service">>,
        <<"demo_procedure">> => <<"io.macula.alice.demo_weather">>,
        <<"announced_by">> => get_alice_ucan()
    },

    {ok, _} = http_post(AliceHecate, "/capabilities/announce", AlicePayload),

    % Wait for mesh propagation
    timer:sleep(2000),

    % Bob discovers weather capabilities
    {ok, DiscoverResp} = http_get(BobHecate, "/capabilities/discover?tags=weather"),

    #{<<"results">> := Results} = jsx:decode(DiscoverResp, [return_maps]),

    % Verify Alice's capability is in results
    ?assert(lists:any(fun(#{<<"capability_mri">> := MRI}) ->
        MRI =:= <<"mri:capability:io.macula.alice/weather">>
    end, Results)),

    ok.
```

---

## Success Criteria

- [x] Command module implemented (`announce_capability_v1.erl`)
- [x] Handler logic complete with all validations (`maybe_announce_capability.erl`)
- [x] Event defined and serializable (`capability_announced_v1.erl`)
- [x] Projection creates/updates `capabilities` table (`capability_announced_v1_to_capabilities.erl`)
- [x] REST API endpoint working (`POST /capabilities/announce`)
- [x] Event published to mesh topic `capability.announced`
- [x] Event signing and verification implemented
- [x] Local ReckonDB storage working
- [x] Local SQLite projection working
- [x] FTS index for search created
- [x] Unit tests passing (>80% coverage)
- [x] Integration tests passing (mesh pub/sub verified)
- [x] E2E test passing (announce + discover flow)
- [x] Documentation updated (API docs, README)

---

## Open Questions

1. **Duplicate announcements:** Should updating a capability be a separate command (`update_capability`) or re-announcing?
   - **Answer:** Separate command for clarity - use `update_capability_v1` (see PLAN_UPDATE_CAPABILITY.md)

2. **Capability versioning:** Should `capability_mri` include version (e.g., `mri:capability:io.macula.alice/weather:1.0.0`)?
   - **Decision needed:** Discuss in Phase 2

3. **Metadata schema:** Should we enforce a schema for `metadata` field?
   - **Answer:** No - keep flexible, but recommend standard fields (version, license, homepage)

4. **Demo procedure validation:** Should we verify demo_procedure is registered before allowing announcement?
   - **Answer:** No - agent may register procedure after announcement. Just validate format.

5. **Rate limiting:** Should we limit announcements per agent per time period?
   - **Answer:** Yes - Phase 2 spam prevention (see PLAN_AGENTIC_SOCIAL_NETWORK.md, Open Question #2)

---

## Related Plans

- [PLAN_DISCOVER_CAPABILITIES.md](PLAN_DISCOVER_CAPABILITIES.md) - Uses capabilities table
- [PLAN_UPDATE_CAPABILITY.md](PLAN_UPDATE_CAPABILITY.md) - Updates existing announcement
- [PLAN_REVOKE_CAPABILITY.md](PLAN_REVOKE_CAPABILITY.md) - Removes announcement
- [PLAN_AGENTIC_SOCIAL_NETWORK.md](PLAN_AGENTIC_SOCIAL_NETWORK.md) - Overall architecture
