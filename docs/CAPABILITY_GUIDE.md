# Capability Building Guide

**Deep dive into building production-ready capabilities for the Macula mesh network.**

---

## Table of Contents

1. [Capability Design](#capability-design)
2. [Implementation Patterns](#implementation-patterns)
3. [Language Examples](#language-examples)
4. [BEAM Clustering (Erlang/Elixir)](#beam-clustering-erlangelixir)
5. [Testing Strategies](#testing-strategies)
6. [Deployment](#deployment)
7. [Monitoring & Debugging](#monitoring--debugging)
8. [Advanced Topics](#advanced-topics)

---

## Capability Design

### What Makes a Good Capability?

A well-designed capability is:

1. **Focused** - Does one thing well
2. **Discoverable** - Rich tags and clear description
3. **Reliable** - Handles errors gracefully
4. **Fast** - Responds quickly (aim for < 100ms)
5. **Documented** - Provides examples and API docs
6. **Versioned** - Uses semantic versioning
7. **Monitored** - Exposes health checks and metrics

### Capability Lifecycle

```
1. Design
   ├─ Define purpose and scope
   ├─ Choose tech stack
   └─ Design API (inputs/outputs)

2. Implement
   ├─ Write service code
   ├─ Add error handling
   └─ Add health checks

3. Test
   ├─ Unit tests
   ├─ Integration tests
   └─ Load tests

4. Deploy
   ├─ Start service
   ├─ Register RPC handlers
   └─ Announce to mesh

5. Monitor
   ├─ Track reputation
   ├─ Monitor errors
   └─ Optimize performance

6. Maintain
   ├─ Respond to feedback
   ├─ Fix bugs
   └─ Release updates
```

---

## Implementation Patterns

### Pattern 1: Stateless Service

**Best for:** API wrappers, data transformation, calculations

```python
# weather_service.py
from flask import Flask, jsonify, request
import requests

app = Flask(__name__)

@app.route('/forecast/<city>', methods=['GET'])
def get_forecast(city):
    # Call external API
    api_key = os.getenv('OPENWEATHER_API_KEY')
    url = f'https://api.openweathermap.org/data/2.5/weather?q={city}&appid={api_key}'

    response = requests.get(url, timeout=3)

    if response.status_code == 200:
        data = response.json()
        return jsonify({
            'city': city,
            'temperature': data['main']['temp'] - 273.15,  # K to C
            'conditions': data['weather'][0]['description'],
            'humidity': data['main']['humidity']
        })
    else:
        return jsonify({'error': 'City not found'}), 404

if __name__ == '__main__':
    app.run(port=5000)
```

**Pros:** Simple, scalable, easy to test

**Cons:** No state persistence, limited to single operations

---

### Pattern 2: Stateful Service with Database

**Best for:** User data, history tracking, personalization

```python
# reminder_service.py
from flask import Flask, jsonify, request
import sqlite3
from datetime import datetime

app = Flask(__name__)
db = sqlite3.connect('reminders.db', check_same_thread=False)

# Initialize DB
db.execute('''
    CREATE TABLE IF NOT EXISTS reminders (
        id INTEGER PRIMARY KEY,
        user_id TEXT,
        message TEXT,
        remind_at TEXT
    )
''')
db.commit()

@app.route('/reminders', methods=['POST'])
def create_reminder():
    data = request.json
    db.execute(
        'INSERT INTO reminders (user_id, message, remind_at) VALUES (?, ?, ?)',
        (data['user_id'], data['message'], data['remind_at'])
    )
    db.commit()
    return jsonify({'ok': True})

@app.route('/reminders/<user_id>', methods=['GET'])
def get_reminders(user_id):
    rows = db.execute(
        'SELECT id, message, remind_at FROM reminders WHERE user_id = ?',
        (user_id,)
    ).fetchall()

    return jsonify({
        'reminders': [
            {'id': r[0], 'message': r[1], 'remind_at': r[2]}
            for r in rows
        ]
    })

if __name__ == '__main__':
    app.run(port=5001)
```

**Pros:** Persistent state, supports complex workflows

**Cons:** Requires database, harder to scale

---

### Pattern 3: Background Worker

**Best for:** Long-running tasks, scheduled jobs, async processing

```python
# image_processor.py
from flask import Flask, jsonify, request
import uuid
from celery import Celery

app = Flask(__name__)
celery = Celery('image_processor', broker='redis://localhost:6379')

jobs = {}  # In-memory job status (use Redis in production)

@celery.task
def process_image(job_id, image_url):
    # Simulate long-running task
    import time
    time.sleep(10)

    # Update job status
    jobs[job_id] = {
        'status': 'completed',
        'result_url': f'https://cdn.example.com/{job_id}.jpg'
    }

@app.route('/process', methods=['POST'])
def start_processing():
    data = request.json
    job_id = str(uuid.uuid4())

    # Start async task
    process_image.delay(job_id, data['image_url'])

    jobs[job_id] = {'status': 'processing'}

    return jsonify({
        'job_id': job_id,
        'status': 'processing'
    })

@app.route('/status/<job_id>', methods=['GET'])
def get_status(job_id):
    job = jobs.get(job_id)
    if not job:
        return jsonify({'error': 'Job not found'}), 404
    return jsonify(job)

if __name__ == '__main__':
    app.run(port=5002)
```

**Pros:** Handles long tasks without blocking

**Cons:** Requires task queue (Redis/RabbitMQ), more complex

---

## Language Examples

### Python (Flask)

```python
# calculator_service.py
from flask import Flask, jsonify, request

app = Flask(__name__)

@app.route('/add', methods=['POST'])
def add():
    data = request.json
    result = data['a'] + data['b']
    return jsonify({'result': result})

@app.route('/health', methods=['GET'])
def health():
    return jsonify({'status': 'healthy'})

if __name__ == '__main__':
    app.run(port=5000)
```

**Register with Hecate:**

```bash
curl -X POST http://localhost:4444/rpc/register \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "io.macula.alice.calculator_add",
    "endpoint": "http://localhost:5000/add"
  }'

curl -X POST http://localhost:4444/capabilities/announce \
  -H "Content-Type: application/json" \
  -d '{
    "capability_mri": "mri:capability:io.macula.alice/calculator",
    "agent_identity": "mri:agent:io.macula.alice/my-agent",
    "tags": ["calculator", "math", "arithmetic"],
    "description": "Simple calculator service",
    "demo_procedure": "io.macula.alice.calculator_add",
    "metadata": {"version": "1.0.0", "language": "python"}
  }'
```

---

### Node.js (Express)

```javascript
// calculator_service.js
const express = require('express');
const app = express();
app.use(express.json());

app.post('/add', (req, res) => {
  const { a, b } = req.body;
  res.json({ result: a + b });
});

app.get('/health', (req, res) => {
  res.json({ status: 'healthy' });
});

app.listen(5000, () => {
  console.log('Calculator service running on port 5000');
});
```

**Register with Hecate:** Same as Python example above.

---

### Erlang (Cowboy)

```erlang
%% calculator_service.erl
-module(calculator_service).
-export([start/0]).

start() ->
    Dispatch = cowboy_router:compile([
        {'_', [
            {"/add", add_handler, []},
            {"/health", health_handler, []}
        ]}
    ]),
    {ok, _} = cowboy:start_clear(http_listener,
        [{port, 5000}],
        #{env => #{dispatch => Dispatch}}
    ),
    io:format("Calculator service running on port 5000~n"),
    receive
        stop -> ok
    end.

%% src/add_handler.erl
-module(add_handler).
-export([init/2]).

init(Req0, State) ->
    {ok, Body, _} = cowboy_req:read_body(Req0),
    #{<<"a">> := A, <<"b">> := B} = jsx:decode(Body, [return_maps]),
    Result = A + B,
    Resp = jsx:encode(#{result => Result}),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        Resp,
        Req0
    ),
    {ok, Req, State}.

%% src/health_handler.erl
-module(health_handler).
-export([init/2]).

init(Req0, State) ->
    Resp = jsx:encode(#{status => <<"healthy">>}),
    Req = cowboy_req:reply(200,
        #{<<"content-type">> => <<"application/json">>},
        Resp,
        Req0
    ),
    {ok, Req, State}.
```

**rebar.config:**

```erlang
{deps, [
    {cowboy, "2.10.0"},
    {jsx, "3.1.0"}
]}.
```

**Build and run:**

```bash
rebar3 get-deps
rebar3 compile
erl -pa _build/default/lib/*/ebin -s calculator_service start
```

**Register with Hecate:** Same as Python example above.

---

### Elixir (Plug/Cowboy)

```elixir
# lib/calculator_service.ex
defmodule CalculatorService do
  use Application

  def start(_type, _args) do
    children = [
      {Plug.Cowboy, scheme: :http, plug: CalculatorService.Router, options: [port: 5000]}
    ]

    opts = [strategy: :one_for_one, name: CalculatorService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end

# lib/calculator_service/router.ex
defmodule CalculatorService.Router do
  use Plug.Router

  plug :match
  plug Plug.Parsers, parsers: [:json], json_decoder: Jason
  plug :dispatch

  post "/add" do
    %{"a" => a, "b" => b} = conn.body_params
    result = a + b

    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{result: result}))
  end

  get "/health" do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Jason.encode!(%{status: "healthy"}))
  end

  match _ do
    send_resp(conn, 404, "Not Found")
  end
end
```

**mix.exs:**

```elixir
def application do
  [
    mod: {CalculatorService, []},
    extra_applications: [:logger]
  ]
end

defp deps do
  [
    {:plug_cowboy, "~> 2.6"},
    {:jason, "~> 1.4"}
  ]
end
```

**Build and run:**

```bash
mix deps.get
mix compile
mix run --no-halt
```

**Register with Hecate:** Same as Python example above.

---

### Elixir (Phoenix - Full Stack)

For production-grade services, use Phoenix:

```bash
mix phx.new calculator_service --no-ecto --no-html --no-assets
cd calculator_service
```

**lib/calculator_service_web/controllers/calculator_controller.ex:**

```elixir
defmodule CalculatorServiceWeb.CalculatorController do
  use CalculatorServiceWeb, :controller

  def add(conn, %{"a" => a, "b" => b}) do
    result = a + b
    json(conn, %{result: result})
  end

  def health(conn, _params) do
    json(conn, %{status: "healthy", version: "1.0.0"})
  end
end
```

**lib/calculator_service_web/router.ex:**

```elixir
defmodule CalculatorServiceWeb.Router do
  use CalculatorServiceWeb, :router

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/api", CalculatorServiceWeb do
    pipe_through :api

    post "/add", CalculatorController, :add
    get "/health", CalculatorController, :health
  end
end
```

**Start Phoenix:**

```bash
mix phx.server
```

**Register with Hecate:**

```bash
curl -X POST http://localhost:4444/rpc/register \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "io.macula.alice.calculator_add",
    "endpoint": "http://localhost:4000/api/add"
  }'
```

---

### Rust (Actix)

```rust
// main.rs
use actix_web::{web, App, HttpResponse, HttpServer, Responder};
use serde::{Deserialize, Serialize};

#[derive(Deserialize)]
struct AddRequest {
    a: i32,
    b: i32,
}

#[derive(Serialize)]
struct AddResponse {
    result: i32,
}

async fn add(req: web::Json<AddRequest>) -> impl Responder {
    let result = req.a + req.b;
    HttpResponse::Ok().json(AddResponse { result })
}

async fn health() -> impl Responder {
    HttpResponse::Ok().json(serde_json::json!({"status": "healthy"}))
}

#[actix_web::main]
async fn main() -> std::io::Result<()> {
    HttpServer::new(|| {
        App::new()
            .route("/add", web::post().to(add))
            .route("/health", web::get().to(health))
    })
    .bind("127.0.0.1:5000")?
    .run()
    .await
}
```

**Register with Hecate:** Same as Python example above.

---

### Go (Gin)

```go
// main.go
package main

import (
    "net/http"
    "github.com/gin-gonic/gin"
)

type AddRequest struct {
    A int `json:"a"`
    B int `json:"b"`
}

type AddResponse struct {
    Result int `json:"result"`
}

func add(c *gin.Context) {
    var req AddRequest
    if err := c.BindJSON(&req); err != nil {
        c.JSON(http.StatusBadRequest, gin.H{"error": err.Error()})
        return
    }

    result := req.A + req.B
    c.JSON(http.StatusOK, AddResponse{Result: result})
}

func health(c *gin.Context) {
    c.JSON(http.StatusOK, gin.H{"status": "healthy"})
}

func main() {
    r := gin.Default()
    r.POST("/add", add)
    r.GET("/health", health)
    r.Run(":5000")
}
```

**Register with Hecate:** Same as Python example above.

---

## BEAM Clustering (Erlang/Elixir)

**For BEAM applications, you can skip the HTTP API entirely and cluster directly with Hecate!**

Hecate is an Erlang node, so your Erlang/Elixir services can connect via distributed Erlang and call functions directly. This provides:

- **Zero serialization overhead** - Native BEAM messages
- **Automatic discovery** - libcluster or partisan
- **Process monitoring** - OTP supervision across nodes
- **Hot code loading** - Deploy without downtime
- **Built-in RPC** - `:rpc.call/4` or GenServer.call across nodes

---

### Pattern 1: Direct Node Clustering

**Hecate runs as:** `hecate@localhost` (or with full hostname)

**Your service connects as:** `calculator@localhost`

#### Erlang Example

**Start Hecate:**

```bash
# Hecate starts with name hecate@localhost
hecate start
```

**Start your service:**

```erlang
%% calculator_app.erl
-module(calculator_app).
-behaviour(application).
-export([start/2, stop/1]).

start(_Type, _Args) ->
    %% Connect to Hecate node
    net_kernel:connect_node('hecate@localhost'),

    %% Register this node's capabilities
    hecate_client:announce_capability(#{
        capability_mri => <<"mri:capability:io.macula.alice/calculator">>,
        agent_identity => <<"mri:agent:io.macula.alice/my-agent">>,
        tags => [<<"calculator">>, <<"math">>],
        description => <<"Erlang calculator service">>,
        handler_module => calculator_server,
        handler_function => add
    }),

    calculator_sup:start_link().

stop(_State) ->
    ok.
```

**Business logic module:**

```erlang
%% calculator_server.erl
-module(calculator_server).
-behaviour(gen_server).
-export([start_link/0, add/2]).
-export([init/1, handle_call/3, handle_cast/2, handle_info/2, terminate/2]).

start_link() ->
    gen_server:start_link({local, ?MODULE}, ?MODULE, [], []).

%% Public API - called by Hecate via RPC
add(A, B) ->
    gen_server:call(?MODULE, {add, A, B}).

%% GenServer callbacks
init([]) ->
    {ok, #{}}.

handle_call({add, A, B}, _From, State) ->
    Result = A + B,
    {reply, {ok, Result}, State}.

handle_cast(_Msg, State) ->
    {noreply, State}.

handle_info(_Info, State) ->
    {noreply, State}.

terminate(_Reason, _State) ->
    ok.
```

**When a remote agent calls the capability:**

```erlang
%% Hecate routes the RPC call to your node
%% NO HTTP involved!
Result = rpc:call('calculator@localhost', calculator_server, add, [10, 5]).
%% Result = {ok, 15}
```

---

#### Elixir Example

**Start your service with node name:**

```bash
iex --name calculator@localhost -S mix
```

**Application module:**

```elixir
# lib/calculator_service/application.ex
defmodule CalculatorService.Application do
  use Application

  def start(_type, _args) do
    # Connect to Hecate
    Node.connect(:"hecate@localhost")

    # Announce capability
    HecateClient.announce_capability(%{
      capability_mri: "mri:capability:io.macula.alice/calculator",
      agent_identity: "mri:agent:io.macula.alice/my-agent",
      tags: ["calculator", "math", "elixir"],
      description: "Elixir calculator service with BEAM clustering",
      handler_module: CalculatorService.Server,
      handler_function: :add
    })

    children = [
      CalculatorService.Server
    ]

    opts = [strategy: :one_for_one, name: CalculatorService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**GenServer module:**

```elixir
# lib/calculator_service/server.ex
defmodule CalculatorService.Server do
  use GenServer

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
  end

  # Public API - called by Hecate via RPC
  def add(a, b) do
    GenServer.call(__MODULE__, {:add, a, b})
  end

  # GenServer callbacks
  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_call({:add, a, b}, _from, state) do
    result = a + b
    {:reply, {:ok, result}, state}
  end
end
```

**RPC call happens natively:**

```elixir
# From another node (via Hecate)
:rpc.call(:"calculator@localhost", CalculatorService.Server, :add, [10, 5])
# {:ok, 15}
```

---

### Pattern 2: Auto-Clustering with libcluster

Use **libcluster** for automatic node discovery and clustering.

**mix.exs:**

```elixir
defp deps do
  [
    {:libcluster, "~> 3.3"}
  ]
end
```

**config/config.exs:**

```elixir
config :libcluster,
  topologies: [
    local: [
      strategy: Cluster.Strategy.Epmd,
      config: [
        hosts: [
          :"hecate@localhost",
          :"calculator@localhost"
        ]
      ]
    ]
  ]
```

**Application supervisor:**

```elixir
defmodule CalculatorService.Application do
  use Application

  def start(_type, _args) do
    topologies = Application.get_env(:libcluster, :topologies, [])

    children = [
      {Cluster.Supervisor, [topologies, [name: CalculatorService.ClusterSupervisor]]},
      CalculatorService.Server
    ]

    opts = [strategy: :one_for_one, name: CalculatorService.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
```

**Nodes automatically discover each other!**

---

### Pattern 3: Partisan Clustering (Production)

For production deployments with NAT/firewalls, use **partisan** instead of distributed Erlang.

**rebar.config:**

```erlang
{deps, [
    {partisan, "5.0.0"}
]}.
```

**sys.config:**

```erlang
[
    {partisan, [
        {peer_service_manager, partisan_pluggable_peer_service_manager},
        {channels, [1]},
        {parallelism, 4},
        {exchange_tick_period, 60000},
        {connect_disterl, false}
    ]}
].
```

**Hecate runs with partisan, your service joins the same partisan cluster:**

```erlang
%% Join partisan cluster
partisan_peer_service:join('hecate@10.0.1.100').
```

---

### Pattern 4: OTP Behaviors Across Nodes

**Supervised RPC handlers:**

```elixir
# lib/calculator_service/rpc_handler.ex
defmodule CalculatorService.RpcHandler do
  use GenServer

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: {:global, __MODULE__})
  end

  @impl true
  def init(_opts) do
    # Register globally so any node can find us
    {:ok, %{}}
  end

  @impl true
  def handle_call({:add, a, b}, _from, state) do
    {:reply, a + b, state}
  end
end

# Call from any node in the cluster
GenServer.call({:global, CalculatorService.RpcHandler}, {:add, 10, 5})
```

---

### Pattern 5: PubSub Across Cluster

Use **Phoenix.PubSub** for distributed pub/sub:

**mix.exs:**

```elixir
defp deps do
  [
    {:phoenix_pubsub, "~> 2.1"}
  ]
end
```

**Application setup:**

```elixir
children = [
  {Phoenix.PubSub, name: CalculatorService.PubSub}
]
```

**Subscribe and publish across nodes:**

```elixir
# Subscribe (on any node)
Phoenix.PubSub.subscribe(CalculatorService.PubSub, "mesh.events")

# Publish (broadcasts to ALL nodes in cluster)
Phoenix.PubSub.broadcast(
  CalculatorService.PubSub,
  "mesh.events",
  {:capability_called, "calculator", 15}
)
```

---

### Advantages of BEAM Clustering

| Feature | HTTP API | BEAM Clustering |
|---------|----------|-----------------|
| **Latency** | ~5-50ms | < 1ms |
| **Serialization** | JSON encode/decode | Native BEAM terms |
| **Type Safety** | Manual validation | Dialyzer specs |
| **Process Links** | Not supported | Full OTP supervision |
| **Hot Reloading** | Restart required | Code reload without downtime |
| **Monitoring** | External tools | Built-in `:observer` |
| **Complexity** | HTTP server + client | Node connection only |

---

### When to Use BEAM Clustering

**✅ Use BEAM clustering when:**
- Both services are BEAM (Erlang/Elixir)
- Low latency is critical (< 5ms)
- You need process supervision across nodes
- You want hot code reloading
- You're comfortable with BEAM distribution

**❌ Use HTTP API when:**
- Services in different languages (Python, Rust, etc.)
- Running across untrusted networks
- Need strict API versioning/compatibility
- Clients are non-BEAM (browsers, mobile apps)

---

### Security Considerations

**Distributed Erlang uses cookies for auth:**

```bash
# Set same cookie on both nodes
export HECATE_COOKIE="secret_cookie_value"
hecate start

# Your service
iex --name calculator@localhost --cookie secret_cookie_value -S mix
```

**For production, use TLS:**

```erlang
%% vm.args
-proto_dist inet_tls
-ssl_dist_optfile /path/to/ssl.conf
```

**ssl.conf:**

```erlang
[
    {server, [
        {certfile, "/path/to/cert.pem"},
        {keyfile, "/path/to/key.pem"},
        {secure_renegotiate, true}
    ]},
    {client, [
        {certfile, "/path/to/cert.pem"},
        {keyfile, "/path/to/key.pem"},
        {secure_renegotiate, true},
        {verify, verify_peer}
    ]}
].
```

---

### Example: Full BEAM Service

**Complete Elixir service that clusters with Hecate:**

```elixir
# mix.exs
defmodule WeatherService.MixProject do
  use Mix.Project

  def project do
    [
      app: :weather_service,
      version: "1.0.0",
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      releases: [
        weather_service: [
          include_executables_for: [:unix],
          applications: [weather_service: :permanent]
        ]
      ]
    ]
  end

  def application do
    [
      mod: {WeatherService.Application, []},
      extra_applications: [:logger]
    ]
  end

  defp deps do
    [
      {:libcluster, "~> 3.3"},
      {:httpoison, "~> 2.0"},
      {:jason, "~> 1.4"}
    ]
  end
end

# lib/weather_service/application.ex
defmodule WeatherService.Application do
  use Application

  def start(_type, _args) do
    topologies = [
      local: [
        strategy: Cluster.Strategy.Epmd,
        config: [hosts: [:"hecate@localhost"]]
      ]
    ]

    children = [
      {Cluster.Supervisor, [topologies, [name: WeatherService.ClusterSupervisor]]},
      WeatherService.Server
    ]

    opts = [strategy: :one_for_one, name: WeatherService.Supervisor]

    # Announce after supervisor starts
    Task.start(fn ->
      :timer.sleep(1000)  # Wait for cluster to form
      announce_capability()
    end)

    Supervisor.start_link(children, opts)
  end

  defp announce_capability do
    HecateClient.announce_capability(%{
      capability_mri: "mri:capability:io.macula.alice/weather-forecast",
      agent_identity: "mri:agent:io.macula.alice/weather-agent",
      tags: ["weather", "forecast", "elixir", "beam"],
      description: "BEAM-native weather forecast service",
      handler_module: WeatherService.Server,
      handler_function: :get_forecast
    })
  end
end

# lib/weather_service/server.ex
defmodule WeatherService.Server do
  use GenServer
  require Logger

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, %{}, name: {:global, __MODULE__})
  end

  # Public API
  def get_forecast(city) do
    GenServer.call({:global, __MODULE__}, {:get_forecast, city})
  end

  # Callbacks
  @impl true
  def init(state) do
    Logger.info("Weather service started")
    {:ok, state}
  end

  @impl true
  def handle_call({:get_forecast, city}, _from, state) do
    result = fetch_weather(city)
    {:reply, result, state}
  end

  defp fetch_weather(city) do
    api_key = System.get_env("OPENWEATHER_API_KEY")
    url = "https://api.openweathermap.org/data/2.5/weather?q=#{city}&appid=#{api_key}"

    case HTTPoison.get(url) do
      {:ok, %{status_code: 200, body: body}} ->
        data = Jason.decode!(body)
        {:ok, %{
          city: city,
          temperature: data["main"]["temp"] - 273.15,
          conditions: data["weather"] |> List.first() |> Map.get("description")
        }}

      {:error, reason} ->
        {:error, reason}
    end
  end
end
```

**Start the service:**

```bash
export OPENWEATHER_API_KEY="your_key"
iex --name weather@localhost --cookie hecate_cluster -S mix
```

**Hecate automatically routes RPC calls to your GenServer!**

No HTTP server needed. Pure BEAM distribution. 🚀

---

## Testing Strategies

### Unit Tests

Test your service logic independently:

```python
# test_calculator.py
import unittest
from calculator_service import app

class TestCalculator(unittest.TestCase):
    def setUp(self):
        self.client = app.test_client()

    def test_add(self):
        response = self.client.post('/add', json={'a': 2, 'b': 3})
        data = response.get_json()
        self.assertEqual(data['result'], 5)

    def test_add_negative(self):
        response = self.client.post('/add', json={'a': -5, 'b': 3})
        data = response.get_json()
        self.assertEqual(data['result'], -2)

if __name__ == '__main__':
    unittest.main()
```

---

### Integration Tests

Test the full flow (service + Hecate):

```python
# test_integration.py
import unittest
import requests
import time

class TestIntegration(unittest.TestCase):
    def test_rpc_call(self):
        # Ensure service is running
        health = requests.get('http://localhost:5000/health')
        self.assertEqual(health.status_code, 200)

        # Call via Hecate RPC
        response = requests.post(
            'http://localhost:4444/rpc/call',
            json={
                'procedure': 'io.macula.alice.calculator_add',
                'args': {'a': 10, 'b': 5},
                'timeout_ms': 5000
            }
        )

        data = response.json()
        self.assertTrue(data['ok'])
        self.assertEqual(data['result']['result'], 15)

if __name__ == '__main__':
    unittest.main()
```

---

### Load Tests

Test performance under load:

```python
# load_test.py
import concurrent.futures
import requests
import time

def call_service():
    response = requests.post(
        'http://localhost:4444/rpc/call',
        json={
            'procedure': 'io.macula.alice.calculator_add',
            'args': {'a': 10, 'b': 5},
            'timeout_ms': 5000
        }
    )
    return response.json()

# Run 100 concurrent requests
start = time.time()
with concurrent.futures.ThreadPoolExecutor(max_workers=100) as executor:
    futures = [executor.submit(call_service) for _ in range(100)]
    results = [f.result() for f in futures]

duration = time.time() - start
success_count = sum(1 for r in results if r.get('ok'))

print(f'Total: 100, Success: {success_count}, Duration: {duration:.2f}s')
print(f'Throughput: {100/duration:.2f} req/s')
```

---

## Deployment

### Production Checklist

- [ ] **Error handling** - All endpoints handle errors gracefully
- [ ] **Health checks** - `/health` endpoint returns service status
- [ ] **Logging** - Structured logging for debugging
- [ ] **Metrics** - Expose Prometheus metrics (optional)
- [ ] **Rate limiting** - Prevent abuse
- [ ] **Authentication** - Use UCAN tokens if needed
- [ ] **HTTPS** - Use TLS for external APIs
- [ ] **Environment config** - Use environment variables for secrets
- [ ] **Process management** - Use systemd/supervisor for daemon
- [ ] **Monitoring** - Set up alerts for errors/downtime

---

### Systemd Service Example

```ini
# /etc/systemd/system/weather-service.service
[Unit]
Description=Weather Forecast Service
After=network.target

[Service]
Type=simple
User=myuser
WorkingDirectory=/home/myuser/weather-service
Environment="OPENWEATHER_API_KEY=your_key_here"
ExecStart=/usr/bin/python3 /home/myuser/weather-service/app.py
Restart=always

[Install]
WantedBy=multi-user.target
```

**Enable and start:**

```bash
sudo systemctl enable weather-service
sudo systemctl start weather-service
sudo systemctl status weather-service
```

---

### Docker Deployment

```dockerfile
# Dockerfile
FROM python:3.11-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY . .

EXPOSE 5000

CMD ["python", "app.py"]
```

**Build and run:**

```bash
docker build -t weather-service .
docker run -d -p 5000:5000 --env OPENWEATHER_API_KEY=your_key weather-service
```

---

## Monitoring & Debugging

### Health Checks

Always implement a `/health` endpoint:

```python
@app.route('/health', methods=['GET'])
def health():
    # Check dependencies
    db_ok = check_database()
    api_ok = check_external_api()

    status = 'healthy' if db_ok and api_ok else 'degraded'

    return jsonify({
        'status': status,
        'version': '1.0.0',
        'uptime_seconds': get_uptime(),
        'dependencies': {
            'database': 'ok' if db_ok else 'error',
            'external_api': 'ok' if api_ok else 'error'
        }
    })
```

---

### Structured Logging

Use structured logs for easy debugging:

```python
import logging
import json

logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

@app.route('/forecast/<city>', methods=['GET'])
def get_forecast(city):
    logger.info(json.dumps({
        'event': 'forecast_request',
        'city': city,
        'timestamp': datetime.utcnow().isoformat()
    }))

    # ... handle request

    logger.info(json.dumps({
        'event': 'forecast_response',
        'city': city,
        'latency_ms': 42,
        'status': 'success'
    }))
```

---

### Debugging RPC Issues

**1. Test locally first:**

```bash
# Direct HTTP call
curl http://localhost:5000/forecast/Amsterdam

# Via Hecate RPC
curl -X POST http://localhost:4444/rpc/call \
  -H "Content-Type: application/json" \
  -d '{
    "procedure": "io.macula.alice.get_weather",
    "args": {"city": "Amsterdam"},
    "timeout_ms": 5000
  }'
```

**2. Check RPC registration:**

```bash
curl http://localhost:4444/rpc/procedures
```

**3. Check Hecate logs:**

```bash
hecate logs --tail 50
```

**4. Check reputation:**

```bash
curl http://localhost:4444/reputation?capability=weather-forecast
```

---

## Advanced Topics

### Multi-Version Support

Support multiple API versions simultaneously:

```python
# v1 endpoint
@app.route('/v1/forecast/<city>', methods=['GET'])
def get_forecast_v1(city):
    # Simple response
    return jsonify({'city': city, 'temp': 15})

# v2 endpoint
@app.route('/v2/forecast/<city>', methods=['GET'])
def get_forecast_v2(city):
    # Enhanced response with more data
    return jsonify({
        'city': city,
        'temp': 15,
        'humidity': 72,
        'wind_speed': 5,
        'forecast_days': [...]
    })
```

**Register both:**

```bash
# v1
curl -X POST http://localhost:4444/rpc/register \
  -d '{"procedure": "io.macula.alice.get_weather_v1", "endpoint": "http://localhost:5000/v1/forecast/{city}"}'

# v2
curl -X POST http://localhost:4444/rpc/register \
  -d '{"procedure": "io.macula.alice.get_weather_v2", "endpoint": "http://localhost:5000/v2/forecast/{city}"}'
```

---

### UCAN Authorization

Restrict access using UCAN tokens:

```python
@app.route('/premium/forecast/<city>', methods=['GET'])
def get_premium_forecast(city):
    # Verify UCAN token
    token = request.headers.get('Authorization')
    if not verify_ucan_token(token, required_capability='premium_access'):
        return jsonify({'error': 'Unauthorized'}), 401

    # Return premium data
    return jsonify({...})

def verify_ucan_token(token, required_capability):
    # Call Hecate to verify
    response = requests.post(
        'http://localhost:4444/ucan/verify',
        json={
            'token_id': token,
            'required_capability': required_capability,
            'required_scope': 'mri:capability:io.macula.alice/premium-weather'
        }
    )
    return response.json().get('valid', False)
```

---

### Batch Operations

Support batch requests for efficiency:

```python
@app.route('/forecast/batch', methods=['POST'])
def get_forecasts_batch():
    data = request.json
    cities = data['cities']

    results = []
    for city in cities:
        forecast = fetch_forecast(city)
        results.append({
            'city': city,
            'forecast': forecast
        })

    return jsonify({'results': results})
```

---

### Caching

Add caching to reduce latency:

```python
from functools import lru_cache
import time

@lru_cache(maxsize=128)
def fetch_forecast(city):
    # Cache for 5 minutes
    cache_key = f'forecast:{city}:{int(time.time() / 300)}'

    # ... fetch from API
    return forecast

@app.route('/forecast/<city>', methods=['GET'])
def get_forecast(city):
    forecast = fetch_forecast(city)
    return jsonify(forecast)
```

---

## Next Steps

- **[QUICKSTART](QUICKSTART.md)** - Get started in 5 minutes
- **[AGENT_GUIDE](AGENT_GUIDE.md)** - Comprehensive agent reference
- **[API_REFERENCE](API_REFERENCE.md)** - Complete API documentation
- **[Examples](../examples/)** - Full example capabilities
- **[Community](https://discord.gg/macula)** - Join the Macula community

---

**Need help?** Join our [Discord](https://discord.gg/macula) or open an issue on [GitHub](https://github.com/hecate-social/hecate-daemon/issues).
