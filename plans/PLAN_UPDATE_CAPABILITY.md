# PLAN: update_capability

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** PLAN_ANNOUNCE_CAPABILITY.md
**Domain:** Capabilities (Command Service)

---

## Business Goal

Enable agents to **update existing capability metadata** without retracting and re-announcing. This allows:
- Version updates (1.0.0 → 1.1.0)
- Description improvements
- Tag refinements
- Metadata changes (homepage, license)
- Demo procedure updates

**Use Case:** Alice announces a weather capability, then improves the description and adds new tags. She shouldn't have to retract and re-announce - just update.

---

## Event Storm

### Command

**Name:** `update_capability_v1`
**Module:** `src/update_capability/update_capability_v1.erl`

**Structure:**
```erlang
-record(update_capability_v1, {
    capability_mri :: binary(),        % "mri:capability:io.macula.alice/weather-forecast"
    agent_identity :: binary(),        % "mri:agent:io.macula.alice/claude-assistant"
    updates :: map(),                  % Fields to update (see below)
    updated_by :: binary()             % UCAN token of updating agent
}).
```

**Updates Map Structure:**
```erlang
#{
    % Optional fields (only include what you want to update)
    <<"tags">> => [binary()],              % New tags (replaces existing)
    <<"description">> => binary(),         % New description
    <<"demo_procedure">> => binary(),      % New demo procedure
    <<"metadata">> => map()                % New metadata (merged with existing)
}
```

**Validation Rules:**
1. `capability_mri` MUST exist (already announced)
2. `agent_identity` MUST match the original announcer (only owner can update)
3. `updates` MUST contain at least one field
4. `tags` (if provided) MUST be non-empty list
5. `description` (if provided) MUST be 10-1000 characters
6. `updated_by` MUST be valid UCAN token
7. UCAN token MUST grant capability to update for this agent

**Example:**
```erlang
Command = #update_capability_v1{
    capability_mri = <<"mri:capability:io.macula.alice/weather-forecast">>,
    agent_identity = <<"mri:agent:io.macula.alice/claude-assistant">>,
    updates = #{
        <<"tags">> => [<<"weather">>, <<"forecast">>, <<"api">>, <<"v2">>],
        <<"description">> => <<"Provides 5-day weather forecasts with improved accuracy using OpenWeather API v2.5">>,
        <<"metadata">> => #{
            <<"version">> => <<"1.1.0">>,
            <<"changelog">> => <<"Added wind speed and UV index">>
        }
    },
    updated_by = <<"eyJhbGc...UCAN_TOKEN">>
}.
```

---

### Event

**Name:** `capability_updated_v1`
**Module:** `src/update_capability/capability_updated_v1.erl`

**Structure:**
```erlang
-record(capability_updated_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    updates :: map(),              % Same as command
    updated_at :: integer()        % Unix timestamp (milliseconds)
}).
```

**Example:**
```erlang
Event = #capability_updated_v1{
    capability_mri = <<"mri:capability:io.macula.alice/weather-forecast">>,
    agent_identity = <<"mri:agent:io.macula.alice/claude-assistant">>,
    updates = #{
        <<"tags">> => [<<"weather">>, <<"forecast">>, <<"api">>, <<"v2">>],
        <<"description">> => <<"Provides 5-day weather forecasts...">>,
        <<"metadata">> => #{<<"version">> => <<"1.1.0">>}
    },
    updated_at = 1738329600000
}.
```

---

### Handler

**Name:** `maybe_update_capability`
**Module:** `src/update_capability/maybe_update_capability.erl`

**Logic:**
1. Validate command structure
2. Check capability exists (query read model)
3. Check agent identity matches original announcer
4. Validate UCAN token
5. Validate update fields (tags, description, etc.)
6. Create event
7. Return error if validation fails

**Pseudocode:**
```erlang
-module(maybe_update_capability).
-export([handle/1]).

handle(#update_capability_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_capability_exists(Cmd#update_capability_v1.capability_mri) end,
        fun() -> validate_ownership(Cmd) end,
        fun() -> validate_updates(Cmd#update_capability_v1.updates) end,
        fun() -> validate_ucan(Cmd#update_capability_v1.updated_by, Cmd#update_capability_v1.agent_identity) end
    ], fun() ->
        {ok, create_event(Cmd)}
    end).

validate_capability_exists(MRI) ->
    case query_capabilities:get_capability(MRI) of
        {ok, _Capability} -> ok;
        {error, not_found} -> {error, <<"Capability not found">>}
    end.

validate_ownership(#update_capability_v1{capability_mri = MRI, agent_identity = Agent}) ->
    case query_capabilities:get_capability(MRI) of
        {ok, #{agent_identity := Agent}} -> ok;
        {ok, #{agent_identity := Other}} -> {error, <<"Only the original announcer can update this capability">>}
    end.

validate_updates(Updates) when map_size(Updates) =:= 0 ->
    {error, <<"At least one field must be updated">>};
validate_updates(Updates) ->
    Validators = [
        fun() -> validate_tags(maps:get(<<"tags">>, Updates, undefined)) end,
        fun() -> validate_description(maps:get(<<"description">>, Updates, undefined)) end,
        fun() -> validate_demo_procedure(maps:get(<<"demo_procedure">>, Updates, undefined)) end
    ],
    run_validators(Validators).

validate_tags(undefined) -> ok;
validate_tags([]) -> {error, <<"Tags must be non-empty list">>};
validate_tags(Tags) when is_list(Tags) -> ok;
validate_tags(_) -> {error, <<"Tags must be a list">>}.

validate_description(undefined) -> ok;
validate_description(Desc) when is_binary(Desc) ->
    Len = byte_size(Desc),
    if
        Len < 10 -> {error, <<"Description too short (min 10 chars)">>};
        Len > 1000 -> {error, <<"Description too long (max 1000 chars)">>};
        true -> ok
    end;
validate_description(_) -> {error, <<"Description must be a string">>}.

create_event(#update_capability_v1{} = Cmd) ->
    #capability_updated_v1{
        capability_mri = Cmd#update_capability_v1.capability_mri,
        agent_identity = Cmd#update_capability_v1.agent_identity,
        updates = Cmd#update_capability_v1.updates,
        updated_at = erlang:system_time(millisecond)
    }.
```

---

### Projection

**Name:** `capability_updated_v1_to_capabilities`
**Module:** `src/../query_capabilities/capability_updated_v1_to_capabilities.erl`

**Logic:**
Update the `capabilities` table with new values, merging metadata.

**Pseudocode:**
```erlang
-module(capability_updated_v1_to_capabilities).
-export([project/1]).

project(Event) ->
    #{
        <<"capability_mri">> := MRI,
        <<"updates">> := Updates,
        <<"updated_at">> := Time
    } = Event,

    %% Build UPDATE statement dynamically based on updates
    SetClauses = build_set_clauses(Updates),
    SQL = <<"UPDATE capabilities SET ", SetClauses/binary, ", updated_at = ? WHERE capability_mri = ?">>,

    Params = build_params(Updates, Time, MRI),
    hecate_store:execute(SQL, Params).

build_set_clauses(Updates) ->
    Clauses = lists:filtermap(fun({Key, _Value}) ->
        case Key of
            <<"tags">> -> {true, <<"tags = ?">>};
            <<"description">> -> {true, <<"description = ?">>};
            <<"demo_procedure">> -> {true, <<"demo_procedure = ?">>};
            <<"metadata">> -> {true, <<"metadata = json_patch(metadata, ?)">>}; % Merge metadata
            _ -> false
        end
    end, maps:to_list(Updates)),
    iolist_to_binary(lists:join(<<", ">>, Clauses)).
```

---

## Mesh Integration

### Topic

**Publish to:** `capability.updated`

**Subscribers:**
- All query_capabilities services (for projection)
- macula-realm (for UI updates)
- Agents following the capability owner

### Payload

```erlang
#{
    type => <<"capability.updated">>,
    capability_mri => <<"mri:capability:io.macula.alice/weather-forecast">>,
    agent_identity => <<"mri:agent:io.macula.alice/claude-assistant">>,
    updates => #{...},
    updated_at => 1738329600000,
    signature => <<"...">>  % UCAN signature
}
```

---

## REST API

### Endpoint

```
PUT /capabilities/:mri
Content-Type: application/json
Authorization: Bearer <ucan-token>

{
  "updates": {
    "tags": ["weather", "forecast", "api", "v2"],
    "description": "Provides 5-day weather forecasts with improved accuracy...",
    "metadata": {
      "version": "1.1.0",
      "changelog": "Added wind speed and UV index"
    }
  }
}

Response 200:
{
  "ok": true,
  "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
  "updated_at": "2026-01-31T12:00:00Z"
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
  "message": "Only the original announcer can update this capability"
}
```

---

## Success Criteria

- [ ] Command validation prevents unauthorized updates
- [ ] Ownership verified (only announcer can update)
- [ ] Metadata merging works correctly (doesn't overwrite unrelated fields)
- [ ] Event published to mesh
- [ ] Projection updates read model
- [ ] REST API endpoint works
- [ ] UI shows updated capability info immediately

---

**Related Plans:**
- [PLAN_ANNOUNCE_CAPABILITY.md](PLAN_ANNOUNCE_CAPABILITY.md)
- [PLAN_RETRACT_CAPABILITY.md](PLAN_RETRACT_CAPABILITY.md)
- [PLAN_CQRS_ARCHITECTURE.md](PLAN_CQRS_ARCHITECTURE.md)
