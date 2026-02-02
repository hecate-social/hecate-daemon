# macula-hecate Developer Guide

This guide is for developers extending macula-hecate with new domains or modifying existing functionality.

## Table of Contents

- [Adding a New Domain](#adding-a-new-domain)
- [Event Versioning](#event-versioning)
- [Testing Patterns](#testing-patterns)
- [Common Pitfalls](#common-pitfalls)
- [Code Style](#code-style)
- [Contributing](#contributing)

---

## Adding a New Domain

This section walks through adding a complete new domain to hecate following CQRS/Event Sourcing patterns.

### Example: Add "Plugins" Domain

**Goal:** Allow agents to register and discover plugins.

**Commands:**
- `register_plugin_v1` - Register a new plugin

**Events:**
- `plugin_registered_v1` - Plugin was registered

**Queries:**
- `find_plugin` - Find plugin by ID
- `list_plugins` - List all plugins with filters

### Step 1: Create Command Service

**Create directory:**

```bash
mkdir -p apps/manage_plugins/src/register_plugin
```

**File structure:**

```
apps/manage_plugins/
├── src/
│   ├── register_plugin/
│   │   ├── register_plugin_v1.erl        # Command
│   │   ├── plugin_registered_v1.erl      # Event
│   │   ├── maybe_register_plugin.erl     # Handler
│   │   └── plugin_registered_v1_to_mesh.erl  # Mesh projection
│   ├── manage_plugins_sup.erl            # Supervisor
│   └── manage_plugins_app.erl            # Application
└── manage_plugins.app.src
```

**1.1 Create Command Module**

```erlang
%% apps/manage_plugins/src/register_plugin/register_plugin_v1.erl
-module(register_plugin_v1).
-export([new/4, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_name/1, get_description/1, get_metadata/1]).

-record(register_plugin_v1, {
    plugin_id :: binary(),
    name :: binary(),
    description :: binary(),
    metadata :: map()
}).

-opaque t() :: #register_plugin_v1{}.
-export_type([t/0]).

new(PluginID, Name, Description, Metadata) ->
    #register_plugin_v1{
        plugin_id = PluginID,
        name = Name,
        description = Description,
        metadata = Metadata
    }.

to_map(#register_plugin_v1{} = Cmd) ->
    #{
        plugin_id => Cmd#register_plugin_v1.plugin_id,
        name => Cmd#register_plugin_v1.name,
        description => Cmd#register_plugin_v1.description,
        metadata => Cmd#register_plugin_v1.metadata
    }.

from_map(#{plugin_id := ID, name := Name, description := Desc, metadata := Meta}) ->
    {ok, new(ID, Name, Desc, Meta)};
from_map(_) ->
    {error, invalid_command}.

get_plugin_id(#register_plugin_v1{plugin_id = ID}) -> ID.
get_name(#register_plugin_v1{name = Name}) -> Name.
get_description(#register_plugin_v1{description = Desc}) -> Desc.
get_metadata(#register_plugin_v1{metadata = Meta}) -> Meta.
```

**1.2 Create Event Module**

```erlang
%% apps/manage_plugins/src/register_plugin/plugin_registered_v1.erl
-module(plugin_registered_v1).
-export([new/4, to_map/1, from_map/1]).
-export([get_plugin_id/1, get_name/1, get_description/1, get_metadata/1, get_registered_at/1]).

-record(plugin_registered_v1, {
    plugin_id :: binary(),
    name :: binary(),
    description :: binary(),
    metadata :: map(),
    registered_at :: integer()
}).

-opaque t() :: #plugin_registered_v1{}.
-export_type([t/0]).

new(PluginID, Name, Description, Metadata) ->
    #plugin_registered_v1{
        plugin_id = PluginID,
        name = Name,
        description = Description,
        metadata = Metadata,
        registered_at = erlang:system_time(millisecond)
    }.

to_map(#plugin_registered_v1{} = Event) ->
    #{
        plugin_id => Event#plugin_registered_v1.plugin_id,
        name => Event#plugin_registered_v1.name,
        description => Event#plugin_registered_v1.description,
        metadata => Event#plugin_registered_v1.metadata,
        registered_at => Event#plugin_registered_v1.registered_at
    }.

from_map(#{plugin_id := ID, name := Name, description := Desc,
           metadata := Meta, registered_at := RegAt}) ->
    {ok, #plugin_registered_v1{
        plugin_id = ID,
        name = Name,
        description = Desc,
        metadata = Meta,
        registered_at = RegAt
    }};
from_map(_) ->
    {error, invalid_event}.

get_plugin_id(#plugin_registered_v1{plugin_id = ID}) -> ID.
get_name(#plugin_registered_v1{name = Name}) -> Name.
get_description(#plugin_registered_v1{description = Desc}) -> Desc.
get_metadata(#plugin_registered_v1{metadata = Meta}) -> Meta.
get_registered_at(#plugin_registered_v1{registered_at = At}) -> At.
```

**1.3 Create Handler Module**

```erlang
%% apps/manage_plugins/src/register_plugin/maybe_register_plugin.erl
-module(maybe_register_plugin).
-export([dispatch/1, handle/1]).

dispatch(Cmd) ->
    reckon_evoq_adapter:dispatch(
        manage_plugins_db,
        Cmd,
        fun handle/1
    ).

handle(Cmd) ->
    PluginID = register_plugin_v1:get_plugin_id(Cmd),
    Name = register_plugin_v1:get_name(Cmd),
    Description = register_plugin_v1:get_description(Cmd),
    Metadata = register_plugin_v1:get_metadata(Cmd),

    %% Business rules
    case validate_plugin_id(PluginID) of
        ok ->
            Event = plugin_registered_v1:new(PluginID, Name, Description, Metadata),
            {ok, [Event]};
        {error, Reason} ->
            {error, Reason}
    end.

validate_plugin_id(PluginID) when is_binary(PluginID), byte_size(PluginID) > 0 ->
    ok;
validate_plugin_id(_) ->
    {error, invalid_plugin_id}.
```

**1.4 Create Mesh Projection**

```erlang
%% apps/manage_plugins/src/register_plugin/plugin_registered_v1_to_mesh.erl
-module(plugin_registered_v1_to_mesh).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    subscription_id :: term()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, SubId} = reckon_evoq_adapter:subscribe(
        manage_plugins_db,
        event_type,
        <<"plugin_registered_v1">>,
        <<"mesh_plugin_registered">>,
        #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{event_type = EventType, data = EventData}}, State) ->
    hecate_mesh_publisher:publish_event(EventType, EventData),
    reckon_evoq_adapter:ack(State#state.subscription_id),
    {noreply, State};
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
```

**1.5 Create Supervisor**

```erlang
%% apps/manage_plugins/src/manage_plugins_sup.erl
-module(manage_plugins_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    application:set_env(evoq, adapter, reckon_evoq_adapter),

    Children = [
        {reckon_db,
            {reckon_db, start_link, [#{name => manage_plugins_db}]},
            permanent, 5000, worker, [reckon_db]},
        {plugin_registered_v1_to_mesh,
            {plugin_registered_v1_to_mesh, start_link, []},
            permanent, 5000, worker, [plugin_registered_v1_to_mesh]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
```

**1.6 Create Application**

```erlang
%% apps/manage_plugins/src/manage_plugins_app.erl
-module(manage_plugins_app).
-behaviour(application).

-export([start/2, stop/1]).

start(_Type, _Args) ->
    manage_plugins_sup:start_link().

stop(_State) ->
    ok.
```

**1.7 Create .app.src**

```erlang
%% apps/manage_plugins/manage_plugins.app.src
{application, manage_plugins, [
    {description, "Plugin registration command service"},
    {vsn, "0.1.0"},
    {registered, [manage_plugins_sup]},
    {mod, {manage_plugins_app, []}},
    {applications, [
        kernel,
        stdlib,
        reckon_db,
        reckon_evoq
    ]},
    {env, []}
]}.
```

### Step 2: Create Query Service

**Create directory:**

```bash
mkdir -p apps/query_plugins/src/{projections,queries}
```

**File structure:**

```
apps/query_plugins/
├── src/
│   ├── projections/
│   │   └── plugin_registered_v1_to_plugins.erl  # Projection
│   ├── queries/
│   │   ├── find_plugin.erl                      # Query
│   │   └── list_plugins.erl                     # Query
│   ├── query_plugins_store.erl                  # SQLite wrapper
│   ├── query_plugins_subscriber.erl             # Event subscriber
│   ├── query_plugins_sup.erl                    # Supervisor
│   └── query_plugins_app.erl                    # Application
└── query_plugins.app.src
```

**2.1 Create Store Module**

```erlang
%% apps/query_plugins/src/query_plugins_store.erl
-module(query_plugins_store).
-export([start_link/0, insert_plugin/5, find_by_id/1, list_all/0]).

-define(DB_PATH, "~/.hecate/query_plugins.db").

start_link() ->
    {ok, Db} = esqlite3:open(?DB_PATH),
    create_schema(Db),
    {ok, Db}.

create_schema(Db) ->
    esqlite3:exec(Db, "
        CREATE TABLE IF NOT EXISTS plugins (
            plugin_id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL,
            metadata TEXT,
            registered_at INTEGER NOT NULL
        )
    "),
    ok.

insert_plugin(PluginID, Name, Desc, Metadata, RegisteredAt) ->
    SQL = "INSERT OR REPLACE INTO plugins (plugin_id, name, description, metadata, registered_at)
           VALUES (?, ?, ?, ?, ?)",
    MetadataJSON = jsx:encode(Metadata),
    {ok, Db} = get_db(),
    esqlite3:exec(Db, SQL, [PluginID, Name, Desc, MetadataJSON, RegisteredAt]).

find_by_id(PluginID) ->
    SQL = "SELECT plugin_id, name, description, metadata, registered_at FROM plugins WHERE plugin_id = ?",
    {ok, Db} = get_db(),
    case esqlite3:q(Db, SQL, [PluginID]) of
        [{ID, Name, Desc, MetaJSON, RegAt}] ->
            {ok, #{
                plugin_id => ID,
                name => Name,
                description => Desc,
                metadata => jsx:decode(MetaJSON, [return_maps]),
                registered_at => RegAt
            }};
        [] ->
            {error, not_found}
    end.

list_all() ->
    SQL = "SELECT plugin_id, name, description, metadata, registered_at FROM plugins",
    {ok, Db} = get_db(),
    Rows = esqlite3:q(Db, SQL),
    {ok, lists:map(fun({ID, Name, Desc, MetaJSON, RegAt}) ->
        #{
            plugin_id => ID,
            name => Name,
            description => Desc,
            metadata => jsx:decode(MetaJSON, [return_maps]),
            registered_at => RegAt
        }
    end, Rows)}.

get_db() ->
    %% In production, store Db in process state
    {ok, Db} = esqlite3:open(?DB_PATH),
    {ok, Db}.
```

**2.2 Create Projection Module**

```erlang
%% apps/query_plugins/src/projections/plugin_registered_v1_to_plugins.erl
-module(plugin_registered_v1_to_plugins).
-export([project/1, project/2]).

project(EventData) when is_map(EventData) ->
    PluginID = maps:get(plugin_id, EventData),
    Name = maps:get(name, EventData),
    Description = maps:get(description, EventData),
    Metadata = maps:get(metadata, EventData),
    RegisteredAt = maps:get(registered_at, EventData),

    query_plugins_store:insert_plugin(PluginID, Name, Description, Metadata, RegisteredAt).

project(Event, _Metadata) ->
    {ok, EventRec} = plugin_registered_v1:from_map(Event),
    PluginID = plugin_registered_v1:get_plugin_id(EventRec),
    Name = plugin_registered_v1:get_name(EventRec),
    Description = plugin_registered_v1:get_description(EventRec),
    Metadata = plugin_registered_v1:get_metadata(EventRec),
    RegisteredAt = plugin_registered_v1:get_registered_at(EventRec),

    query_plugins_store:insert_plugin(PluginID, Name, Description, Metadata, RegisteredAt).
```

**2.3 Create Subscriber Module**

```erlang
%% apps/query_plugins/src/query_plugins_subscriber.erl
-module(query_plugins_subscriber).
-behaviour(gen_server).

-export([start_link/0]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

-record(state, {
    subscription_id :: term(),
    store_id :: term()
}).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

init([]) ->
    {ok, SubId} = reckon_evoq_adapter:subscribe(
        manage_plugins_db,
        event_type,
        <<"plugin_registered_v1">>,
        <<"query_plugins_subscriber">>,
        #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_id = SubId}}.

handle_call(_Msg, _From, State) ->
    {reply, {error, unknown_call}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info({event, #evoq_event{data = EventData} = Event}, State) ->
    case plugin_registered_v1_to_plugins:project(EventData) of
        ok ->
            reckon_evoq_adapter:ack(State#state.subscription_id),
            {noreply, State};
        {error, Reason} ->
            error_logger:error_msg("Projection failed: ~p~n", [Reason]),
            {noreply, State}  % Don't ack, will retry
    end;
handle_info(_Msg, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
```

**2.4 Create Query Modules**

```erlang
%% apps/query_plugins/src/queries/find_plugin.erl
-module(find_plugin).
-export([execute/1]).

execute(PluginID) ->
    query_plugins_store:find_by_id(PluginID).
```

```erlang
%% apps/query_plugins/src/queries/list_plugins.erl
-module(list_plugins).
-export([execute/0]).

execute() ->
    query_plugins_store:list_all().
```

**2.5 Create Supervisor**

```erlang
%% apps/query_plugins/src/query_plugins_sup.erl
-module(query_plugins_sup).
-behaviour(supervisor).

-export([start_link/0, init/1]).

start_link() ->
    supervisor:start_link({local, ?MODULE}, ?MODULE, []).

init([]) ->
    Children = [
        {query_plugins_store,
            {query_plugins_store, start_link, []},
            permanent, 5000, worker, [query_plugins_store]},
        {query_plugins_subscriber,
            {query_plugins_subscriber, start_link, []},
            permanent, 5000, worker, [query_plugins_subscriber]}
    ],
    {ok, {{one_for_one, 10, 10}, Children}}.
```

**2.6 Create .app.src**

```erlang
%% apps/query_plugins/query_plugins.app.src
{application, query_plugins, [
    {description, "Plugin discovery query service"},
    {vsn, "0.1.0"},
    {registered, [query_plugins_sup]},
    {mod, {query_plugins_app, []}},
    {applications, [
        kernel,
        stdlib,
        reckon_evoq,
        esqlite,
        jsx
    ]},
    {env, []}
]}.
```

### Step 3: Add API Endpoints

**Create API handler:**

```erlang
%% apps/hecate_api/src/hecate_api_plugins.erl
-module(hecate_api_plugins).
-export([init/2]).

init(Req0, State) ->
    Method = cowboy_req:method(Req0),
    Path = cowboy_req:path(Req0),

    Req = case {Method, Path} of
        {<<"POST">>, <<"/plugins/register">>} -> handle_register(Req0);
        {<<"GET">>, <<"/plugins/discover">>} -> handle_discover(Req0);
        {<<"GET">>, <<"/plugins/", PluginID/binary>>} -> handle_get(Req0, PluginID);
        _ -> cowboy_req:reply(404, #{}, jsx:encode(#{ok => false, error => <<"not_found">>}), Req0)
    end,

    {ok, Req, State}.

handle_register(Req0) ->
    {ok, Body, Req1} = cowboy_req:read_body(Req0),
    Data = jsx:decode(Body, [return_maps]),

    PluginID = maps:get(<<"plugin_id">>, Data),
    Name = maps:get(<<"name">>, Data),
    Description = maps:get(<<"description">>, Data, <<"">>),
    Metadata = maps:get(<<"metadata">>, Data, #{}),

    Cmd = register_plugin_v1:new(PluginID, Name, Description, Metadata),
    case maybe_register_plugin:dispatch(Cmd) of
        {ok, Version, _Events} ->
            Response = jsx:encode(#{ok => true, result => #{version => Version}}),
            cowboy_req:reply(200, #{<<"content-type">> => <<"application/json">>}, Response, Req1);
        {error, Reason} ->
            Response = jsx:encode(#{ok => false, error => atom_to_binary(Reason, utf8)}),
            cowboy_req:reply(400, #{<<"content-type">> => <<"application/json">>}, Response, Req1)
    end.

handle_discover(Req0) ->
    case list_plugins:execute() of
        {ok, Plugins} ->
            Response = jsx:encode(#{ok => true, result => #{plugins => Plugins}}),
            cowboy_req:reply(200, #{<<"content-type">> => <<"application/json">>}, Response, Req0);
        {error, Reason} ->
            Response = jsx:encode(#{ok => false, error => atom_to_binary(Reason, utf8)}),
            cowboy_req:reply(500, #{<<"content-type">> => <<"application/json">>}, Response, Req0)
    end.

handle_get(Req0, PluginID) ->
    case find_plugin:execute(PluginID) of
        {ok, Plugin} ->
            Response = jsx:encode(#{ok => true, result => Plugin}),
            cowboy_req:reply(200, #{<<"content-type">> => <<"application/json">>}, Response, Req0);
        {error, not_found} ->
            Response = jsx:encode(#{ok => false, error => <<"not_found">>}),
            cowboy_req:reply(404, #{<<"content-type">> => <<"application/json">>}, Response, Req0)
    end.
```

**Update Cowboy routes:**

```erlang
%% apps/hecate_api/src/hecate_api_app.erl (add to routes)
Routes = [
    %% ... existing routes ...
    {"/plugins/register", hecate_api_plugins, []},
    {"/plugins/discover", hecate_api_plugins, []},
    {"/plugins/:plugin_id", hecate_api_plugins, []}
].
```

### Step 4: Add to Release

**Update root rebar.config:**

```erlang
{relx, [
    {release, {hecate, "0.1.0"}, [
        %% ... existing apps ...
        manage_plugins,
        query_plugins
    ]},
    %% ...
]}.
```

### Step 5: Test

**Compile:**

```bash
rebar3 compile
```

**Test command:**

```bash
curl -X POST http://localhost:4444/plugins/register \
  -H "Content-Type: application/json" \
  -d '{
    "plugin_id": "weather-plugin",
    "name": "Weather Plugin",
    "description": "Provides weather forecasts",
    "metadata": {"version": "1.0.0"}
  }'
```

**Test query:**

```bash
curl http://localhost:4444/plugins/discover
```

---

## Event Versioning

### Why Version Events?

- Schema evolution (add/remove/rename fields)
- Backward compatibility (old projections still work)
- Event store is append-only (can't modify old events)

### Versioning Strategy

**Use explicit version suffix:**

- `plugin_registered_v1` → `plugin_registered_v2`

**Not:**

- ~~`plugin_registered_2024`~~ (date-based)
- ~~`plugin_registered_new`~~ (ambiguous)

### Adding a New Field (v1 → v2)

**Scenario:** Add `author` field to `plugin_registered_v1`.

**Step 1: Create v2 Event**

```erlang
%% plugin_registered_v2.erl
-record(plugin_registered_v2, {
    plugin_id :: binary(),
    name :: binary(),
    description :: binary(),
    metadata :: map(),
    author :: binary(),  %% NEW FIELD
    registered_at :: integer()
}).
```

**Step 2: Update Handler to Emit v2**

```erlang
%% maybe_register_plugin.erl
handle(Cmd) ->
    %% ...
    Author = register_plugin_v1:get_author(Cmd),  % New getter
    Event = plugin_registered_v2:new(PluginID, Name, Description, Metadata, Author),
    {ok, [Event]}.
```

**Step 3: Update Projection to Handle Both**

```erlang
%% plugin_registered_to_plugins.erl
project(EventData) when is_map(EventData) ->
    PluginID = maps:get(plugin_id, EventData),
    Name = maps:get(name, EventData),
    Description = maps:get(description, EventData),
    Metadata = maps:get(metadata, EventData),
    Author = maps:get(author, EventData, <<"unknown">>),  % Default for v1
    RegisteredAt = maps:get(registered_at, EventData),

    query_plugins_store:insert_plugin(PluginID, Name, Description, Metadata, Author, RegisteredAt).
```

**Step 4: Subscribe to Both Event Types**

```erlang
%% query_plugins_subscriber.erl
init([]) ->
    {ok, SubId1} = reckon_evoq_adapter:subscribe(
        manage_plugins_db, event_type, <<"plugin_registered_v1">>,
        <<"query_plugins_subscriber_v1">>, #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, SubId2} = reckon_evoq_adapter:subscribe(
        manage_plugins_db, event_type, <<"plugin_registered_v2">>,
        <<"query_plugins_subscriber_v2">>, #{start_from => 0, subscriber_pid => self()}
    ),
    {ok, #state{subscription_ids = [SubId1, SubId2]}}.
```

**Result:** Old v1 events still project correctly, new v2 events include author.

---

## Testing Patterns

### Unit Tests (EUnit)

**Test command creation:**

```erlang
%% test/register_plugin_v1_tests.erl
-module(register_plugin_v1_tests).
-include_lib("eunit/include/eunit.hrl").

new_command_test() ->
    Cmd = register_plugin_v1:new(<<"plugin-1">>, <<"Test">>, <<"Desc">>, #{}),
    ?assertEqual(<<"plugin-1">>, register_plugin_v1:get_plugin_id(Cmd)).

to_map_test() ->
    Cmd = register_plugin_v1:new(<<"plugin-1">>, <<"Test">>, <<"Desc">>, #{}),
    Map = register_plugin_v1:to_map(Cmd),
    ?assertMatch(#{plugin_id := <<"plugin-1">>}, Map).
```

**Test handler logic:**

```erlang
%% test/maybe_register_plugin_tests.erl
-module(maybe_register_plugin_tests).
-include_lib("eunit/include/eunit.hrl").

handle_valid_command_test() ->
    Cmd = register_plugin_v1:new(<<"plugin-1">>, <<"Test">>, <<"Desc">>, #{}),
    {ok, Events} = maybe_register_plugin:handle(Cmd),
    ?assertEqual(1, length(Events)).

handle_invalid_plugin_id_test() ->
    Cmd = register_plugin_v1:new(<<"">>, <<"Test">>, <<"Desc">>, #{}),
    ?assertMatch({error, invalid_plugin_id}, maybe_register_plugin:handle(Cmd)).
```

**Run tests:**

```bash
rebar3 eunit --app=manage_plugins
```

### Integration Tests (Common Test)

**Test event flow:**

```erlang
%% test/plugins_SUITE.erl
-module(plugins_SUITE).
-compile(export_all).
-include_lib("common_test/include/ct.hrl").

all() -> [register_and_query_plugin].

init_per_suite(Config) ->
    application:ensure_all_started(manage_plugins),
    application:ensure_all_started(query_plugins),
    Config.

end_per_suite(_Config) ->
    application:stop(query_plugins),
    application:stop(manage_plugins).

register_and_query_plugin(_Config) ->
    %% Dispatch command
    Cmd = register_plugin_v1:new(<<"plugin-1">>, <<"Test">>, <<"Desc">>, #{}),
    {ok, _, _} = maybe_register_plugin:dispatch(Cmd),

    %% Wait for projection
    timer:sleep(100),

    %% Query should return plugin
    {ok, Plugin} = find_plugin:execute(<<"plugin-1">>),
    <<"Test">> = maps:get(name, Plugin),

    ok.
```

**Run tests:**

```bash
rebar3 ct --suite=test/plugins_SUITE
```

---

## Common Pitfalls

### 1. Forgetting to Ack Events

**Wrong:**

```erlang
handle_info({event, #evoq_event{data = EventData}}, State) ->
    project(EventData),
    {noreply, State}.  % ❌ Forgot to ack!
```

**Right:**

```erlang
handle_info({event, #evoq_event{data = EventData}}, State) ->
    ok = project(EventData),
    reckon_evoq_adapter:ack(State#state.subscription_id),  % ✅ Ack
    {noreply, State}.
```

### 2. Blocking Event Flow with DB I/O

**Wrong:**

```erlang
project(EventData) ->
    esqlite3:exec(Db, "INSERT INTO ...", [...]),  % ❌ Blocks subscriber
    ok.
```

**Right:**

```erlang
project(EventData) ->
    spawn(fun() ->
        esqlite3:exec(Db, "INSERT INTO ...", [...])  % ✅ Async
    end),
    ok.
```

Or use dedicated worker pool.

### 3. Missing Event Version in from_map/1

**Wrong:**

```erlang
from_map(#{plugin_id := ID, name := Name}) ->  % ❌ What if v2 has more fields?
    {ok, new(ID, Name)}.
```

**Right:**

```erlang
from_map(#{plugin_id := ID, name := Name, author := Author}) ->
    {ok, new(ID, Name, Author)};
from_map(#{plugin_id := ID, name := Name}) ->  % v1 compat
    {ok, new(ID, Name, <<"unknown">>)}.
```

### 4. Using Atoms for Dynamic Data

**Wrong:**

```erlang
PluginID = list_to_atom(binary_to_list(BinID)),  % ❌ Atom table exhaustion!
```

**Right:**

```erlang
PluginID = BinID,  % ✅ Use binaries
```

### 5. Not Handling Projection Failures

**Wrong:**

```erlang
project(EventData) ->
    esqlite3:exec(...),  % ❌ What if DB is locked?
    ok.
```

**Right:**

```erlang
project(EventData) ->
    case esqlite3:exec(...) of
        ok -> ok;
        {error, Reason} ->
            error_logger:error_msg("Projection failed: ~p~n", [Reason]),
            {error, Reason}  % Caller can decide to retry
    end.
```

---

## Code Style

### Erlang Conventions

**Module naming:**
- snake_case: `maybe_register_plugin.erl`

**Function naming:**
- snake_case: `get_plugin_id/1`

**Record naming:**
- snake_case: `#register_plugin_v1{}`

**Atoms:**
- snake_case: `invalid_plugin_id`

### Pattern Matching Over Case

**Prefer:**

```erlang
handle_event(plugin_registered_v1, EventData) ->
    %% ...
handle_event(plugin_registered_v2, EventData) ->
    %% ...
```

**Over:**

```erlang
handle_event(EventType, EventData) ->
    case EventType of
        plugin_registered_v1 -> %% ...
        plugin_registered_v2 -> %% ...
    end.
```

### Opaque Types

**Export type but hide implementation:**

```erlang
-record(register_plugin_v1, { ... }).
-opaque t() :: #register_plugin_v1{}.
-export_type([t/0]).
```

**Users:**

```erlang
-spec dispatch(register_plugin_v1:t()) -> {ok, term()} | {error, term()}.
dispatch(Cmd) -> %% ...
```

---

## Contributing

### Pull Request Checklist

- [ ] Code compiles without warnings
- [ ] Unit tests added and passing
- [ ] Integration tests added if needed
- [ ] Documentation updated (CLAUDE.md, API.md, etc.)
- [ ] CHANGELOG.md updated
- [ ] Event versioning considered
- [ ] Projection handles old and new event versions
- [ ] API endpoints documented with curl examples
- [ ] No horizontal layering (vertical slicing only)

### Running Pre-commit Checks

```bash
rebar3 compile
rebar3 dialyzer
rebar3 eunit
rebar3 ct
rebar3 cover
```

### Code Review Guidelines

**Reviewers check for:**

1. **Vertical slicing** - No `services/`, `repositories/`, `utils/` layers
2. **Event naming** - Past tense (`plugin_registered_v1`, not `register_plugin`)
3. **Command naming** - Present tense (`register_plugin_v1`)
4. **Immutability** - No mutation of records or maps
5. **Error handling** - Pattern matching, not try/catch
6. **Documentation** - EDoc on all exported functions

---

## Resources

- ReckonDB docs: https://hexdocs.pm/reckon_db
- Evoq docs: https://hexdocs.pm/evoq
- CQRS: https://martinfowler.com/bliki/CQRS.html
- Event Sourcing: https://martinfowler.com/eaaDev/EventSourcing.html
- Erlang/OTP Design Principles: https://www.erlang.org/doc/design_principles/users_guide.html
