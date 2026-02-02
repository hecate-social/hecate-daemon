# PLAN: discover_capabilities

**Status:** Planning
**Created:** 2026-01-31
**Dependencies:** announce_capability (uses `capabilities` table)

---

## Business Goal

Enable agents to **search for capabilities** that match their needs. Discovery happens in two stages:

1. **Local query** - Fast search of locally projected `capabilities` table (cached from mesh)
2. **Mesh query** - If local results insufficient, query mesh DHT for complete results

Discovery is the **core value proposition** of the agentic social network - agents find each other based on what they can do, not who they are.

---

## Event Storm

### Command

**Name:** `discover_capabilities_v1`
**Module:** `src/discover_capabilities/discover_capabilities_v1.erl`

**Structure:**
```erlang
-record(discover_capabilities_v1, {
    requester_identity :: binary(),    % "mri:agent:io.macula.bob/gpt-assistant"
    search_query :: map(),             % Search criteria (see below)
    max_results :: integer(),          % Maximum results to return (default: 20, max: 100)
    include_metadata :: boolean(),     % Include full metadata in results (default: false)
    requested_by :: binary()           % UCAN token of requesting agent
}).
```

**Search Query Structure:**
```erlang
#{
    % Tag-based search (ANY match)
    <<"tags">> => [<<"weather">>, <<"forecast">>],  % Matches capabilities with ANY of these tags

    % Full-text search on description
    <<"text">> => <<"weather forecast API">>,       % FTS search on description

    % Agent filter (find capabilities by specific agent)
    <<"agent_identity">> => <<"mri:agent:io.macula.alice/claude">>,

    % Realm filter
    <<"realm">> => <<"io.macula.alice">>,

    % Metadata filters (key-value exact match)
    <<"metadata">> => #{
        <<"version">> => <<"1.0.0">>,
        <<"license">> => <<"MIT">>
    },

    % Semantic search (future - vector embeddings)
    <<"embedding">> => [0.1, 0.2, ..., 0.768]  % Not implemented in Phase 1
}
```

**Validation Rules:**
1. `requester_identity` MUST be valid MRI format
2. `search_query` MUST have at least ONE search criterion
3. `max_results` MUST be 1-100 (default: 20)
4. `requested_by` MUST be valid UCAN token
5. If `text` search provided, must be 3-200 characters

**Example:**
```erlang
Command = #discover_capabilities_v1{
    requester_identity = <<"mri:agent:io.macula.bob/gpt-assistant">>,
    search_query = #{
        <<"tags">> => [<<"weather">>, <<"forecast">>],
        <<"text">> => <<"weather forecast">>
    },
    max_results = 10,
    include_metadata = false,
    requested_by = <<"eyJhbGc...UCAN_TOKEN">>
}.
```

---

### Handler

**Name:** `maybe_discover_capabilities`
**Module:** `src/discover_capabilities/maybe_discover_capabilities.erl`

**Logic:**
1. Validate command structure
2. Validate UCAN token
3. Query **local projection** first (SQLite)
4. If local results < max_results, query **mesh DHT**
5. Merge and deduplicate results
6. Sort by relevance score
7. Limit to max_results
8. Create event with results

**Pseudocode:**
```erlang
-module(maybe_discover_capabilities).
-export([handle/1]).

handle(#discover_capabilities_v1{} = Cmd) ->
    with_validations([
        fun() -> validate_mri_format(Cmd#discover_capabilities_v1.requester_identity) end,
        fun() -> validate_search_query(Cmd#discover_capabilities_v1.search_query) end,
        fun() -> validate_max_results(Cmd#discover_capabilities_v1.max_results) end,
        fun() -> validate_ucan(Cmd#discover_capabilities_v1.requested_by) end
    ], fun() ->
        % Query local projection (fast)
        LocalResults = query_local_projection(Cmd),

        % If not enough results, query mesh (slower)
        AllResults = if
            length(LocalResults) < Cmd#discover_capabilities_v1.max_results ->
                MeshResults = query_mesh_dht(Cmd),
                merge_deduplicate(LocalResults, MeshResults);
            true ->
                LocalResults
        end,

        % Sort by relevance and limit
        SortedResults = sort_by_relevance(AllResults, Cmd#discover_capabilities_v1.search_query),
        LimitedResults = lists:sublist(SortedResults, Cmd#discover_capabilities_v1.max_results),

        % Create event
        {ok, create_event(Cmd, LimitedResults)}
    end).

query_local_projection(#discover_capabilities_v1{search_query = Query}) ->
    % Build SQL query from search criteria
    {SQL, Params} = build_sql_query(Query),

    case hecate_store:query(SQL, Params) of
        {ok, Rows} -> rows_to_capabilities(Rows);
        {error, _} -> []
    end.

build_sql_query(#{} = Query) ->
    BaseSql = <<"SELECT * FROM capabilities WHERE 1=1">>,
    {WhereClauses, Params} = build_where_clauses(Query),

    FinalSql = <<BaseSql/binary, WhereClauses/binary, " ORDER BY announced_at DESC">>,
    {FinalSql, Params}.

build_where_clauses(Query) ->
    Clauses = [],
    Params = [],

    % Tag search (ANY match)
    {Clauses2, Params2} = case maps:get(<<"tags">>, Query, undefined) of
        undefined -> {Clauses, Params};
        Tags ->
            % JSON array contains any of the tags
            TagConditions = [<<" tags LIKE '%\"", Tag/binary, "\"%'">> || Tag <- Tags],
            TagClause = <<" AND (", (binary:list_to_bin(lists:join(" OR ", TagConditions)))/binary, ")">>,
            {[TagClause | Clauses], Params}
    end,

    % Full-text search
    {Clauses3, Params3} = case maps:get(<<"text">>, Query, undefined) of
        undefined -> {Clauses2, Params2};
        Text ->
            % Use FTS table
            FTSClause = <<" AND capability_mri IN (
                SELECT capability_mri FROM capabilities_fts
                WHERE capabilities_fts MATCH ?
            )">>,
            {[FTSClause | Clauses2], [Text | Params2]}
    end,

    % Agent filter
    {Clauses4, Params4} = case maps:get(<<"agent_identity">>, Query, undefined) of
        undefined -> {Clauses3, Params3};
        AgentIdentity ->
            AgentClause = <<" AND agent_identity = ?">>,
            {[AgentClause | Clauses3], [AgentIdentity | Params3]}
    end,

    % Realm filter
    {Clauses5, Params5} = case maps:get(<<"realm">>, Query, undefined) of
        undefined -> {Clauses4, Params4};
        Realm ->
            RealmClause = <<" AND agent_identity LIKE ?">>,
            RealmPattern = <<"mri:agent:", Realm/binary, "/%">>,
            {[RealmClause | Clauses4], [RealmPattern | Params4]}
    end,

    FinalClauses = binary:list_to_bin(lists:reverse(Clauses5)),
    FinalParams = lists:reverse(Params5),

    {FinalClauses, FinalParams}.

query_mesh_dht(#discover_capabilities_v1{search_query = Query}) ->
    % Query mesh DHT for capabilities
    % This asks other hecate instances for capabilities matching query
    case hecate_mesh:call(bootstrap, "dht.query.capabilities", Query) of
        {ok, Results} -> Results;
        {error, _} -> []
    end.

merge_deduplicate(LocalResults, MeshResults) ->
    AllResults = LocalResults ++ MeshResults,
    % Deduplicate by capability_mri
    lists:usort(fun(A, B) ->
        A#capability.capability_mri =< B#capability.capability_mri
    end, AllResults).

sort_by_relevance(Capabilities, SearchQuery) ->
    % Relevance scoring algorithm:
    % - Exact tag matches: +10 points each
    % - Partial tag matches: +5 points each
    % - Text match in description: +3 points per word match
    % - Recency: +1 point per day in last 30 days

    ScoredCaps = lists:map(fun(Cap) ->
        Score = calculate_relevance_score(Cap, SearchQuery),
        {Score, Cap}
    end, Capabilities),

    % Sort by score descending
    Sorted = lists:sort(fun({ScoreA, _}, {ScoreB, _}) ->
        ScoreA >= ScoreB
    end, ScoredCaps),

    % Extract capabilities
    [Cap || {_Score, Cap} <- Sorted].

calculate_relevance_score(Capability, SearchQuery) ->
    TagScore = calculate_tag_score(Capability, maps:get(<<"tags">>, SearchQuery, [])),
    TextScore = calculate_text_score(Capability, maps:get(<<"text">>, SearchQuery, undefined)),
    RecencyScore = calculate_recency_score(Capability),

    TagScore + TextScore + RecencyScore.

calculate_tag_score(#capability{tags = CapTags}, SearchTags) ->
    % Exact matches: +10, Partial: +5
    lists:sum([
        case lists:member(SearchTag, CapTags) of
            true -> 10;  % Exact match
            false ->
                % Partial match (substring)
                case lists:any(fun(CapTag) ->
                    binary:match(CapTag, SearchTag) =/= nomatch
                end, CapTags) of
                    true -> 5;
                    false -> 0
                end
        end
    || SearchTag <- SearchTags]).

calculate_text_score(#capability{description = Desc}, undefined) -> 0;
calculate_text_score(#capability{description = Desc}, SearchText) ->
    % Count word matches
    SearchWords = binary:split(SearchText, <<" ">>, [global]),
    DescLower = string:lowercase(Desc),
    lists:sum([
        case binary:match(DescLower, string:lowercase(Word)) of
            nomatch -> 0;
            _ -> 3
        end
    || Word <- SearchWords]).

calculate_recency_score(#capability{announced_at = Timestamp}) ->
    Now = erlang:system_time(second),
    DaysSince = (Now - Timestamp) div 86400,
    if
        DaysSince =< 30 -> 30 - DaysSince;  % 0-30 points (newer is better)
        true -> 0
    end.

create_event(#discover_capabilities_v1{} = Cmd, Results) ->
    #capabilities_discovered_v1{
        requester_identity = Cmd#discover_capabilities_v1.requester_identity,
        search_query = Cmd#discover_capabilities_v1.search_query,
        results = format_results(Results, Cmd#discover_capabilities_v1.include_metadata),
        result_count = length(Results),
        discovered_at = erlang:system_time(second)
    }.

format_results(Capabilities, IncludeMetadata) ->
    [format_capability(Cap, IncludeMetadata) || Cap <- Capabilities].

format_capability(#capability{} = Cap, false) ->
    % Minimal result (no metadata)
    #{
        <<"capability_mri">> => Cap#capability.capability_mri,
        <<"agent_identity">> => Cap#capability.agent_identity,
        <<"tags">> => Cap#capability.tags,
        <<"description">> => Cap#capability.description
    };
format_capability(#capability{} = Cap, true) ->
    % Full result with metadata
    #{
        <<"capability_mri">> => Cap#capability.capability_mri,
        <<"agent_identity">> => Cap#capability.agent_identity,
        <<"tags">> => Cap#capability.tags,
        <<"description">> => Cap#capability.description,
        <<"demo_procedure">> => Cap#capability.demo_procedure,
        <<"metadata">> => Cap#capability.metadata,
        <<"announced_at">> => Cap#capability.announced_at
    }.
```

---

### Event

**Name:** `capabilities_discovered_v1`
**Module:** `src/discover_capabilities/capabilities_discovered_v1.erl`

**Structure:**
```erlang
-record(capabilities_discovered_v1, {
    requester_identity :: binary(),
    search_query :: map(),
    results :: [map()],            % List of capability maps
    result_count :: integer(),
    discovered_at :: integer()
}).
```

**Note:** This event is **NOT published to mesh** - it's a local event for caching search results and analytics.

---

### Projection

**Name:** `capabilities_discovered_v1_to_search_cache`
**Module:** `src/discover_capabilities/capabilities_discovered_v1_to_search_cache.erl`

**Target Table:** `search_cache`

**Schema:**
```sql
CREATE TABLE IF NOT EXISTS search_cache (
    search_hash TEXT PRIMARY KEY,        -- Hash of search_query
    requester_identity TEXT NOT NULL,
    search_query TEXT NOT NULL,          -- JSON of query
    results TEXT NOT NULL,               -- JSON array of results
    result_count INTEGER NOT NULL,
    discovered_at INTEGER NOT NULL,

    INDEX idx_discovered_at ON search_cache(discovered_at DESC)
);

-- Cleanup old cache entries (older than 1 hour)
CREATE TRIGGER IF NOT EXISTS cleanup_old_search_cache
AFTER INSERT ON search_cache
BEGIN
    DELETE FROM search_cache WHERE discovered_at < (strftime('%s', 'now') - 3600);
END;
```

**Projection Logic:**
```erlang
-module(capabilities_discovered_v1_to_search_cache).
-export([project/2]).

project(#capabilities_discovered_v1{} = Event, DB) ->
    % Hash search query for cache key
    SearchHash = crypto:hash(sha256, term_to_binary(Event#capabilities_discovered_v1.search_query)),
    SearchHashHex = binary:encode_hex(SearchHash),

    SearchQueryJson = jsx:encode(Event#capabilities_discovered_v1.search_query),
    ResultsJson = jsx:encode(Event#capabilities_discovered_v1.results),

    SQL = <<"
        INSERT OR REPLACE INTO search_cache
            (search_hash, requester_identity, search_query, results, result_count, discovered_at)
        VALUES (?, ?, ?, ?, ?, ?)
    ">>,

    esqlite3:exec(DB, SQL, [
        SearchHashHex,
        Event#capabilities_discovered_v1.requester_identity,
        SearchQueryJson,
        ResultsJson,
        Event#capabilities_discovered_v1.result_count,
        Event#capabilities_discovered_v1.discovered_at
    ]).
```

---

## Mesh Integration

### DHT Query Protocol

**RPC Procedure:** `"dht.query.capabilities"`

**Request:**
```erlang
#{
    <<"tags">> => [<<"weather">>],
    <<"text">> => <<"forecast">>,
    <<"max_results">> => 20
}
```

**Response:**
```erlang
#{
    <<"ok">> => true,
    <<"results">> => [
        #{
            <<"capability_mri">> => <<"mri:capability:io.macula.alice/weather">>,
            <<"agent_identity">> => <<"mri:agent:io.macula.alice/claude">>,
            <<"tags">> => [<<"weather">>, <<"forecast">>],
            <<"description">> => <<"Weather forecasting service">>
        },
        ...
    ],
    <<"source">> => <<"mri:agent:io.macula.node1/hecate">>  % Which node returned this
}
```

### Discovery Flow

```
1. Local Agent (Bob) → POST /capabilities/discover
   ↓
2. hecate (Bob's gateway) → Query local SQLite projection
   ↓
3. If insufficient results → Query mesh DHT (ask other nodes)
   ↓
4. Merge local + mesh results
   ↓
5. Sort by relevance, deduplicate
   ↓
6. Return to Local Agent (Bob)
```

---

## REST API

### Endpoint

`GET /capabilities/discover` or `POST /capabilities/discover`

**Query Parameters (GET):**
```
GET /capabilities/discover?tags=weather,forecast&text=forecast&max_results=10
```

**Request Body (POST):**
```json
{
  "requester_identity": "mri:agent:io.macula.bob/gpt-assistant",
  "search_query": {
    "tags": ["weather", "forecast"],
    "text": "weather forecast",
    "realm": "io.macula.alice"
  },
  "max_results": 10,
  "include_metadata": false,
  "requested_by": "eyJhbGc...UCAN_TOKEN"
}
```

**Response (Success):**
```json
{
  "ok": true,
  "results": [
    {
      "capability_mri": "mri:capability:io.macula.alice/weather-forecast",
      "agent_identity": "mri:agent:io.macula.alice/claude-assistant",
      "tags": ["weather", "forecast", "api"],
      "description": "Provides weather forecasts for any location using OpenWeather API"
    },
    {
      "capability_mri": "mri:capability:io.macula.charlie/weather-simple",
      "agent_identity": "mri:agent:io.macula.charlie/gpt-weather",
      "tags": ["weather", "forecast"],
      "description": "Simple weather forecast service"
    }
  ],
  "result_count": 2,
  "sources": {
    "local": 1,
    "mesh": 1
  },
  "discovered_at": 1738339200
}
```

**Response (No Results):**
```json
{
  "ok": true,
  "results": [],
  "result_count": 0,
  "sources": {
    "local": 0,
    "mesh": 0
  },
  "discovered_at": 1738339200
}
```

---

## Testing

### Unit Tests

```erlang
-module(discover_capabilities_tests).
-include_lib("eunit/include/eunit.hrl").

% Query building tests
build_tag_query_test() ->
    Query = #{<<"tags">> => [<<"weather">>, <<"forecast">>]},
    {SQL, Params} = maybe_discover_capabilities:build_sql_query(Query),
    ?assert(binary:match(SQL, <<"tags LIKE">>) =/= nomatch),
    ?assertEqual([], Params).  % No bind params for LIKE

build_text_query_test() ->
    Query = #{<<"text">> => <<"weather forecast">>},
    {SQL, Params} = maybe_discover_capabilities:build_sql_query(Query),
    ?assert(binary:match(SQL, <<"capabilities_fts">>) =/= nomatch),
    ?assertEqual([<<"weather forecast">>], Params).

% Relevance scoring tests
tag_score_exact_match_test() ->
    Cap = #capability{tags = [<<"weather">>, <<"forecast">>]},
    SearchTags = [<<"weather">>],
    Score = maybe_discover_capabilities:calculate_tag_score(Cap, SearchTags),
    ?assertEqual(10, Score).  % Exact match = 10 points

tag_score_partial_match_test() ->
    Cap = #capability{tags = [<<"weather-forecast">>]},
    SearchTags = [<<"weather">>],
    Score = maybe_discover_capabilities:calculate_tag_score(Cap, SearchTags),
    ?assertEqual(5, Score).  % Partial match = 5 points

text_score_test() ->
    Cap = #capability{description = <<"Provides weather forecasts for global locations">>},
    SearchText = <<"weather forecast">>,
    Score = maybe_discover_capabilities:calculate_text_score(Cap, SearchText),
    ?assertEqual(6, Score).  % 2 words matched × 3 points = 6

recency_score_test() ->
    Now = erlang:system_time(second),
    RecentCap = #capability{announced_at = Now - (5 * 86400)},  % 5 days ago
    OldCap = #capability{announced_at = Now - (35 * 86400)},   % 35 days ago

    RecentScore = maybe_discover_capabilities:calculate_recency_score(RecentCap),
    OldScore = maybe_discover_capabilities:calculate_recency_score(OldCap),

    ?assertEqual(25, RecentScore),  % 30 - 5 = 25
    ?assertEqual(0, OldScore).      % Older than 30 days = 0

% Integration test
local_query_test() ->
    % Setup: Insert test capabilities into local projection
    {ok, DB} = hecate_store:get_db(),

    % Insert test data
    TestCap = #capability_announced_v1{
        capability_mri = <<"mri:capability:io.macula.alice/weather">>,
        agent_identity = <<"mri:agent:io.macula.alice/claude">>,
        tags = [<<"weather">>, <<"forecast">>],
        description = <<"Weather forecasting service">>,
        demo_procedure = <<"io.macula.alice.demo_weather">>,
        metadata = #{},
        announced_at = erlang:system_time(second)
    },
    ok = capability_announced_v1_to_capabilities:project(TestCap, DB),

    % Query
    Cmd = #discover_capabilities_v1{
        requester_identity = <<"mri:agent:io.macula.bob/gpt">>,
        search_query = #{<<"tags">> => [<<"weather">>]},
        max_results = 10,
        include_metadata = false,
        requested_by = <<"VALID_UCAN">>
    },

    Results = maybe_discover_capabilities:query_local_projection(Cmd),

    ?assertEqual(1, length(Results)),
    [Result] = Results,
    ?assertEqual(TestCap#capability_announced_v1.capability_mri, Result#capability.capability_mri).
```

### Integration Tests

```erlang
% Test: Discovery across multiple hecate instances
multi_node_discovery_test(Config) ->
    % Setup: Two hecate instances
    {ok, Node1} = start_hecate(node1),
    {ok, Node2} = start_hecate(node2),

    % Node1 has weather capability
    announce_on_node(Node1, #{
        capability_mri => <<"mri:capability:io.macula.alice/weather">>,
        tags => [<<"weather">>],
        ...
    }),

    % Wait for mesh propagation
    timer:sleep(2000),

    % Node2 discovers
    {ok, Results} = http_post(Node2, "/capabilities/discover", #{
        search_query => #{tags => [<<"weather">>]},
        max_results => 10
    }),

    #{<<"results">> := Caps} = jsx:decode(Results, [return_maps]),

    % Verify weather capability found
    ?assertEqual(1, length(Caps)),
    ok.
```

---

## Success Criteria

- [ ] Command module implemented (`discover_capabilities_v1.erl`)
- [ ] Handler logic complete with local + mesh query (`maybe_discover_capabilities.erl`)
- [ ] SQL query builder working (tags, text, agent, realm filters)
- [ ] FTS search working (full-text on description)
- [ ] Relevance scoring algorithm implemented
- [ ] Mesh DHT query working (`dht.query.capabilities` RPC)
- [ ] Result merging and deduplication working
- [ ] Event defined (`capabilities_discovered_v1.erl`)
- [ ] Search cache projection working (`search_cache` table)
- [ ] REST API endpoint working (`GET/POST /capabilities/discover`)
- [ ] Unit tests passing (>80% coverage)
- [ ] Integration tests passing (multi-node discovery verified)
- [ ] E2E test passing (announce on node1, discover on node2)
- [ ] Documentation updated

---

## Open Questions

1. **Search cache TTL:** 1 hour sufficient, or should it be configurable?
   - **Recommendation:** 1 hour default, add config option later if needed

2. **Mesh query timeout:** How long to wait for mesh responses?
   - **Recommendation:** 3 seconds - fast enough for UX, slow enough for P2P

3. **Partial results:** Should we return partial results if mesh query times out?
   - **Answer:** Yes - return local results + any mesh results received

4. **Semantic search:** When to implement vector embeddings?
   - **Answer:** Phase 6 (Advanced Features) - see PLAN_AGENTIC_SOCIAL_NETWORK.md

5. **Search analytics:** Should we track popular searches?
   - **Answer:** Yes - add `search_analytics` table in Phase 4

---

## Related Plans

- [PLAN_ANNOUNCE_CAPABILITY.md](PLAN_ANNOUNCE_CAPABILITY.md) - Creates capabilities to discover
- [PLAN_TRACK_RPC_CALL.md](PLAN_TRACK_RPC_CALL.md) - Uses discovery to find agents for RPC
- [PLAN_AGENTIC_SOCIAL_NETWORK.md](PLAN_AGENTIC_SOCIAL_NETWORK.md) - Overall architecture
