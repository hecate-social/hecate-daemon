# Event Envelope Guide

## Overview

This guide explains how business events in Hecate daemon fit into the evoq event envelope structure. Understanding this is **critical** for implementing commands, events, and projections correctly.

## The evoq_event Envelope

All events in the reckon-db/evoq ecosystem are wrapped in an `evoq_event` record:

```erlang
-record(evoq_event, {
    event_id :: binary(),              %% UUID (auto-generated)
    event_type :: binary(),            %% "CapabilityAnnounced.v1"
    stream_id :: binary(),             %% "capability-mri:capability:..."
    version :: non_neg_integer(),      %% Stream version (0, 1, 2, ...)
    data :: map() | binary(),          %% ← YOUR BUSINESS EVENT GOES HERE
    metadata :: map(),                 %% Correlation, causation, context
    tags :: [binary()] | undefined,    %% Cross-stream queries
    timestamp :: integer(),            %% Event creation time (ms)
    epoch_us :: integer(),             %% Microsecond timestamp
    data_content_type :: binary(),     %% "application/json"
    metadata_content_type :: binary()  %% "application/json"
}).
```

## Where Your Business Event Fits

**Your event module produces/consumes ONLY the `data` field.**

### Example: capability_announced_v1

```erlang
%%% File: capability_announced_v1.erl
-module(capability_announced_v1).
-export([new/6, to_map/1, from_map/1, get_*/1]).

%% Internal representation (opaque)
-record(capability_announced_v1, {
    capability_mri :: binary(),
    agent_identity :: binary(),
    tags :: [binary()],
    description :: binary(),
    demo_procedure :: binary() | undefined,
    metadata :: map()
}).

%% to_map/1 produces JUST the payload (for evoq_event.data)
to_map(#capability_announced_v1{...} = Event) ->
    #{
        capability_mri => get_mri(Event),
        agent_identity => get_agent_id(Event),
        tags => get_tags(Event),
        description => get_description(Event),
        demo_procedure => get_demo_procedure(Event),
        metadata => get_metadata(Event)
    }.

%% from_map/1 consumes JUST the payload (extracted from evoq_event.data)
from_map(#{
    capability_mri := MRI,
    agent_identity := AgentID,
    tags := Tags,
    description := Desc
} = Data) ->
    {ok, #capability_announced_v1{
        capability_mri = MRI,
        agent_identity = AgentID,
        tags = Tags,
        description = Desc,
        demo_procedure = maps:get(demo_procedure, Data, undefined),
        metadata = maps:get(metadata, Data, #{})
    }}.
```

## Complete Event Lifecycle

### 1. Command Handling (Command Service)

```erlang
%%% Handler returns events as your business event type
-module(maybe_announce_capability).

handle(Cmd) ->
    %% Validate command...

    %% Create event (internal representation)
    Event = capability_announced_v1:new(
        MRI, AgentID, Tags, Desc, DemoProc, Metadata
    ),

    %% Return list of events
    {ok, [Event]}.
```

### 2. Aggregate Execution (via evoq)

```erlang
%%% Aggregate executes command, returns events
-module(capability_aggregate).

execute(Cmd, State) ->
    %% Delegate to handler
    {ok, Events} = maybe_announce_capability:handle(Cmd),
    {ok, Events}.  %% Returns [#capability_announced_v1{}]
```

### 3. Event Wrapping (evoq does this automatically)

```erlang
%%% evoq/reckon_evoq wraps your event in the envelope
EventMap = capability_announced_v1:to_map(Event),  %% Calls your to_map/1

EvqEvent = #evoq_event{
    event_id = generate_uuid(),
    event_type = <<"CapabilityAnnounced.v1">>,  %% Derived from module name
    stream_id = <<"capability-", (get_mri(Event))/binary>>,
    version = CurrentVersion + 1,
    data = EventMap,  %% ← YOUR to_map/1 result
    metadata = #{
        correlation_id => get_correlation_id(),
        causation_id => get_command_id(),
        timestamp => erlang:system_time(millisecond)
    },
    tags = derive_tags(EventMap),
    timestamp = erlang:system_time(millisecond),
    epoch_us = erlang:system_time(microsecond)
}.
```

### 4. Storage (ReckonDB)

```erlang
%%% Stored in ReckonDB as JSON map
#{
    event_type => <<"CapabilityAnnounced.v1">>,
    data => #{
        capability_mri => <<"mri:capability:io.macula/weather">>,
        agent_identity => <<"did:macula:agent123">>,
        tags => [<<"weather">>],
        description => <<"Weather service">>,
        demo_procedure => null,
        metadata => #{}
    },
    metadata => #{
        correlation_id => <<"req-abc">>,
        causation_id => <<"cmd-xyz">>,
        timestamp => 1703001234567
    },
    tags => [<<"realm:io.macula">>]
}
```

### 5. Event Subscription (Query Service)

```erlang
%%% Projection receives evoq_event map
-module(query_capabilities_projections).

handle_event(#{
    event_type := <<"CapabilityAnnounced.v1">>,
    data := EventData,        %% ← Extract 'data' field
    metadata := Metadata      %% ← Extract 'metadata' field
}) ->
    %% Deserialize using your from_map/1
    {ok, Event} = capability_announced_v1:from_map(EventData),

    %% Project to read model
    capability_announced_v1_to_capabilities:project(Event, Metadata).
```

### 6. Projection to Read Model

```erlang
%%% Projection inserts into SQLite
-module(capability_announced_v1_to_capabilities).

project(Event, Metadata) ->
    %% Extract from business event
    MRI = capability_announced_v1:get_mri(Event),
    AgentID = capability_announced_v1:get_agent_id(Event),
    Tags = capability_announced_v1:get_tags(Event),

    %% Extract from metadata
    CorrelationID = maps:get(correlation_id, Metadata, null),

    %% Insert into SQLite
    Sql = "INSERT INTO capabilities (...) VALUES (...)",
    query_capabilities_store:execute(Sql, [MRI, AgentID, ...]).
```

## Event Naming Conventions

| Component | Format | Example |
|-----------|--------|---------|
| **event_type (binary)** | PascalCase.vN | `<<"CapabilityAnnounced.v1">>` |
| **Module name** | snake_case_vN | `capability_announced_v1.erl` |
| **Record name** | snake_case_vN | `#capability_announced_v1{}` |
| **Stream ID** | `{type}-{id}` | `<<"capability-mri:capability:...">>` |

## Metadata Standard Fields

Always include in `evoq_event.metadata`:

```erlang
#{
    correlation_id => <<"req-abc">>,   %% Request ID linking operations
    causation_id => <<"cmd-xyz">>,     %% Command ID that caused this
    user_id => <<"did:macula:agent">>, %% Who triggered it
    realm_id => <<"io.macula">>,       %% Which realm
    timestamp => 1703001234567         %% When it happened
}
```

## Tags for Cross-Stream Queries

Use `evoq_event.tags` for querying across aggregates:

```erlang
tags => [
    <<"realm:io.macula">>,
    <<"plugin:weather">>,
    <<"agent:did:macula:agent123">>
]

%% Query all events for a realm:
Events = reckon_db:query_by_tag(Store, <<"realm:io.macula">>).
```

## Event Versioning

Version events in the type name:

```erlang
%% Version 1
event_type => <<"CapabilityAnnounced.v1">>
%% Module: capability_announced_v1.erl

%% Version 2 (added new fields)
event_type => <<"CapabilityAnnounced.v2">>
%% Module: capability_announced_v2.erl

%% Handle both in projections:
handle_event(#{event_type := <<"CapabilityAnnounced.v1">>, data := D}) ->
    %% Upgrade v1 to v2 format
    D2 = D#{new_field => default_value},
    process_v2(D2);

handle_event(#{event_type := <<"CapabilityAnnounced.v2">>, data := D}) ->
    process_v2(D).
```

## Key Takeaways

1. ✅ **Your event modules produce/consume ONLY the `data` field**
2. ✅ **evoq handles the envelope** (event_id, stream_id, version, timestamps)
3. ✅ **Metadata is separate** from your business event data
4. ✅ **Tags enable cross-stream queries** (realm, plugin, agent)
5. ✅ **Event type is a binary** (not an atom), use version suffix
6. ✅ **Stream ID follows convention** `{aggregate_type}-{aggregate_id}`
7. ✅ **to_map/1** returns payload for `evoq_event.data`
8. ✅ **from_map/1** takes payload from `evoq_event.data`

## Testing Event Envelope Handling

```erlang
%%% Test that your event fits correctly in the envelope
-module(capability_announced_v1_test).
-include_lib("eunit/include/eunit.hrl").

envelope_round_trip_test() ->
    %% 1. Create business event
    Event = capability_announced_v1:new(
        <<"mri:capability:io.macula/test">>,
        <<"did:macula:agent">>,
        [<<"test">>],
        <<"Test">>,
        undefined,
        #{}
    ),

    %% 2. Serialize to payload (for evoq_event.data)
    Payload = capability_announced_v1:to_map(Event),

    %% 3. Simulate evoq envelope
    EvqEvent = #{
        event_type => <<"CapabilityAnnounced.v1">>,
        data => Payload,  %% Your payload goes here
        metadata => #{
            correlation_id => <<"test-123">>,
            timestamp => erlang:system_time(millisecond)
        }
    },

    %% 4. Extract payload from envelope (like projection does)
    #{data := ExtractedPayload, metadata := Metadata} = EvqEvent,

    %% 5. Deserialize payload
    {ok, Event2} = capability_announced_v1:from_map(ExtractedPayload),

    %% 6. Verify round-trip worked
    ?assertEqual(
        capability_announced_v1:get_mri(Event),
        capability_announced_v1:get_mri(Event2)
    ).
```

## See Also

- `CLAUDE.md` - Event Structure and Envelope section
- `include/evoq_event.hrl` - evoq_event record definition
- `/home/rl/work/github.com/reckon-db-org/evoq/include/evoq_types.hrl` - Original source
- `/home/rl/work/github.com/reckon-db-org/reckon-db/guides/event_sourcing.md` - Comprehensive guide
